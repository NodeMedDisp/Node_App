const crypto = require("crypto");

const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {
  FieldValue,
  Timestamp,
  getFirestore,
} = require("firebase-admin/firestore");
const {setGlobalOptions} = require("firebase-functions");
const {HttpsError, onCall} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");

initializeApp();
setGlobalOptions({region: "us-central1", maxInstances: 10});

const db = getFirestore();

function requireAuthenticated(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Sign in before using this feature.");
  }

  return request.auth;
}

function requireVerifiedEmail(request) {
  const auth = requireAuthenticated(request);
  const email = normalizeEmail(auth.token.email);

  if (!email || auth.token.email_verified !== true) {
    throw new HttpsError(
      "failed-precondition",
      "A verified account email is required.",
    );
  }

  return {auth, email};
}

function normalizeEmail(value) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function requireString(data, field, label, maxLength = 500) {
  const value = data && typeof data[field] === "string" ? data[field].trim() : "";

  if (!value) {
    throw new HttpsError("invalid-argument", `${label} is required.`);
  }

  if (value.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${label} is longer than the supported limit.`,
    );
  }

  return value;
}

async function requireActiveClinicMember(clinicId, uid) {
  const memberRef = db.doc(`clinics/${clinicId}/members/${uid}`);
  const memberSnapshot = await memberRef.get();

  if (!memberSnapshot.exists || memberSnapshot.data().active !== true) {
    throw new HttpsError(
      "permission-denied",
      "Your account is not an active member of this clinic.",
    );
  }

  return memberSnapshot.data();
}

function invitationIdFor(clinicId, patientId) {
  return crypto
    .createHash("sha256")
    .update(`${clinicId}|${patientId}`)
    .digest("hex")
    .slice(0, 40);
}

function timestampToIso(value) {
  return value instanceof Timestamp ? value.toDate().toISOString() : null;
}

exports.createPatientInvite = onCall(async (request) => {
  const auth = requireAuthenticated(request);
  const data = request.data || {};
  const clinicId = requireString(data, "clinicId", "Clinic ID", 150);
  const patientId = requireString(data, "patientId", "Patient ID", 150);
  const recipientEmail = normalizeEmail(data.recipientEmail);

  if (!recipientEmail || !recipientEmail.includes("@")) {
    throw new HttpsError(
      "invalid-argument",
      "Enter a valid patient email address.",
    );
  }

  await requireActiveClinicMember(clinicId, auth.uid);

  const patientRef = db.doc(`clinics/${clinicId}/patients/${patientId}`);
  const clinicRef = db.doc(`clinics/${clinicId}`);
  const [patientSnapshot, clinicSnapshot] = await Promise.all([
    patientRef.get(),
    clinicRef.get(),
  ]);

  if (!patientSnapshot.exists) {
    throw new HttpsError("not-found", "The selected patient no longer exists.");
  }

  const patientData = patientSnapshot.data();
  if (patientData.linkedPatientUid) {
    throw new HttpsError(
      "failed-precondition",
      "This patient is already linked to a patient account.",
    );
  }

  let recipientUid = null;
  try {
    recipientUid = (await getAuth().getUserByEmail(recipientEmail)).uid;
  } catch (error) {
    if (error && error.code !== "auth/user-not-found") {
      logger.error("Could not look up invitation recipient", error);
      throw new HttpsError(
        "internal",
        "The invitation recipient could not be checked.",
      );
    }
  }

  const inviteId = invitationIdFor(clinicId, patientId);
  const inviteRef = db.doc(`patientInvites/${inviteId}`);
  const now = Timestamp.now();
  const clinicDisplayName =
    clinicSnapshot.data()?.displayName ||
    clinicSnapshot.data()?.name ||
    clinicId;
  const providerEmail = normalizeEmail(auth.token.email);

  await db.runTransaction(async (transaction) => {
    const [currentPatient, existingInvite] = await Promise.all([
      transaction.get(patientRef),
      transaction.get(inviteRef),
    ]);

    if (!currentPatient.exists) {
      throw new HttpsError("not-found", "The selected patient no longer exists.");
    }

    if (currentPatient.data().linkedPatientUid) {
      throw new HttpsError(
        "failed-precondition",
        "This patient is already linked to a patient account.",
      );
    }

    transaction.set(inviteRef, {
      clinicId,
      clinicDisplayName,
      patientId,
      patientDisplayName:
        currentPatient.data().displayName || patientData.displayName || "Patient",
      recipientEmailNormalized: recipientEmail,
      recipientUid,
      providerUid: auth.uid,
      providerEmail,
      status: "pending",
      createdAt: existingInvite.exists
        ? existingInvite.data().createdAt || now
        : now,
      updatedAt: now,
    });

    transaction.update(patientRef, {
      pendingInviteId: inviteId,
      pendingInviteEmail: recipientEmail,
      pendingInviteCreatedAt: now,
      updatedAt: now,
    });
  });

  logger.info("Patient invitation created", {
    clinicId,
    patientId,
    inviteId,
    providerUid: auth.uid,
    accountAlreadyExists: recipientUid !== null,
  });

  return {
    inviteId,
    recipientEmail,
    accountAlreadyExists: recipientUid !== null,
  };
});

exports.listMyPendingPatientInvites = onCall(async (request) => {
  const {email} = requireVerifiedEmail(request);

  const snapshot = await db
    .collection("patientInvites")
    .where("recipientEmailNormalized", "==", email)
    .get();

  const invites = snapshot.docs
    .map((document) => ({id: document.id, ...document.data()}))
    .filter((invite) => invite.status === "pending")
    .sort((a, b) => {
      const aMillis = a.createdAt instanceof Timestamp ? a.createdAt.toMillis() : 0;
      const bMillis = b.createdAt instanceof Timestamp ? b.createdAt.toMillis() : 0;
      return bMillis - aMillis;
    })
    .map((invite) => ({
      id: invite.id,
      clinicId: invite.clinicId,
      clinicDisplayName: invite.clinicDisplayName || invite.clinicId,
      patientId: invite.patientId,
      patientDisplayName: invite.patientDisplayName || "Recovery Plan",
      providerEmail: invite.providerEmail || "",
      createdAt: timestampToIso(invite.createdAt),
    }));

  return {invites};
});

exports.acceptPatientInvite = onCall(async (request) => {
  const {auth, email} = requireVerifiedEmail(request);
  const inviteId = requireString(request.data || {}, "inviteId", "Invitation ID", 150);
  const inviteRef = db.doc(`patientInvites/${inviteId}`);
  const linkRef = db.doc(`patientLinks/${auth.uid}`);
  const now = Timestamp.now();

  const result = await db.runTransaction(async (transaction) => {
    const [inviteSnapshot, existingLink] = await Promise.all([
      transaction.get(inviteRef),
      transaction.get(linkRef),
    ]);

    if (!inviteSnapshot.exists) {
      throw new HttpsError("not-found", "This invitation no longer exists.");
    }

    const invite = inviteSnapshot.data();

    if (normalizeEmail(invite.recipientEmailNormalized) !== email) {
      throw new HttpsError(
        "permission-denied",
        "This invitation belongs to a different email address.",
      );
    }

    if (invite.status === "accepted" && invite.acceptedByUid === auth.uid) {
      return {
        clinicId: invite.clinicId,
        patientId: invite.patientId,
        alreadyAccepted: true,
      };
    }

    if (invite.status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        "This invitation is no longer pending.",
      );
    }

    const patientRef = db.doc(
      `clinics/${invite.clinicId}/patients/${invite.patientId}`,
    );
    const patientSnapshot = await transaction.get(patientRef);

    if (!patientSnapshot.exists) {
      throw new HttpsError("not-found", "The invited recovery plan no longer exists.");
    }

    const patient = patientSnapshot.data();

    if (patient.linkedPatientUid && patient.linkedPatientUid !== auth.uid) {
      throw new HttpsError(
        "already-exists",
        "This recovery plan is already linked to another account.",
      );
    }

    if (existingLink.exists) {
      const existing = existingLink.data();
      const samePlan =
        existing.clinicId === invite.clinicId &&
        existing.patientId === invite.patientId;

      if (!samePlan) {
        throw new HttpsError(
          "already-exists",
          "This account is already permanently linked to another recovery plan.",
        );
      }
    }

    transaction.set(linkRef, {
      clinicId: invite.clinicId,
      patientId: invite.patientId,
      patientDisplayName:
        patient.displayName || invite.patientDisplayName || "Recovery Plan",
      patientEmail: email,
      permanent: true,
      createdAt: existingLink.exists
        ? existingLink.data().createdAt || now
        : now,
      linkedAt: now,
      inviteId,
    });

    transaction.update(patientRef, {
      linkedPatientUid: auth.uid,
      linkedPatientEmail: email,
      linkedAt: now,
      pendingInviteId: FieldValue.delete(),
      pendingInviteEmail: FieldValue.delete(),
      pendingInviteCreatedAt: FieldValue.delete(),
      updatedAt: now,
    });

    transaction.update(inviteRef, {
      status: "accepted",
      acceptedAt: now,
      acceptedByUid: auth.uid,
      recipientUid: auth.uid,
      updatedAt: now,
    });

    return {
      clinicId: invite.clinicId,
      patientId: invite.patientId,
      alreadyAccepted: false,
    };
  });

  logger.info("Patient invitation accepted", {
    inviteId,
    patientUid: auth.uid,
    clinicId: result.clinicId,
    patientId: result.patientId,
    alreadyAccepted: result.alreadyAccepted,
  });

  return result;
});

exports.declinePatientInvite = onCall(async (request) => {
  const {auth, email} = requireVerifiedEmail(request);
  const inviteId = requireString(request.data || {}, "inviteId", "Invitation ID", 150);
  const inviteRef = db.doc(`patientInvites/${inviteId}`);
  const now = Timestamp.now();

  await db.runTransaction(async (transaction) => {
    const inviteSnapshot = await transaction.get(inviteRef);

    if (!inviteSnapshot.exists) {
      throw new HttpsError("not-found", "This invitation no longer exists.");
    }

    const invite = inviteSnapshot.data();

    if (normalizeEmail(invite.recipientEmailNormalized) !== email) {
      throw new HttpsError(
        "permission-denied",
        "This invitation belongs to a different email address.",
      );
    }

    if (invite.status !== "pending") {
      return;
    }

    const patientRef = db.doc(
      `clinics/${invite.clinicId}/patients/${invite.patientId}`,
    );
    const patientSnapshot = await transaction.get(patientRef);

    transaction.update(inviteRef, {
      status: "declined",
      declinedAt: now,
      declinedByUid: auth.uid,
      recipientUid: auth.uid,
      updatedAt: now,
    });

    if (
      patientSnapshot.exists &&
      patientSnapshot.data().pendingInviteId === inviteId
    ) {
      transaction.update(patientRef, {
        pendingInviteId: FieldValue.delete(),
        pendingInviteEmail: FieldValue.delete(),
        pendingInviteCreatedAt: FieldValue.delete(),
        updatedAt: now,
      });
    }
  });

  return {declined: true};
});

exports.savePatientRecoveryProgress = onCall(async (request) => {
  const {auth} = requireVerifiedEmail(request);
  const data = request.data || {};
  const dateKey = requireString(data, "date", "Recovery date", 10);
  const rawEntries = Array.isArray(data.entries) ? data.entries : null;

  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateKey)) {
    throw new HttpsError(
      "invalid-argument",
      "Recovery date must use YYYY-MM-DD format.",
    );
  }

  if (!rawEntries || rawEntries.length === 0 || rawEntries.length > 25) {
    throw new HttpsError(
      "invalid-argument",
      "Send between 1 and 25 recovery entries at a time.",
    );
  }

  const parsedDate = new Date(`${dateKey}T12:00:00.000Z`);
  if (Number.isNaN(parsedDate.getTime())) {
    throw new HttpsError("invalid-argument", "Recovery date is invalid.");
  }

  const tomorrow = new Date();
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  if (parsedDate.getTime() > tomorrow.getTime()) {
    throw new HttpsError(
      "invalid-argument",
      "Future recovery activity cannot be recorded.",
    );
  }

  const sanitizedEntries = rawEntries.map((entry, index) => {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
      throw new HttpsError(
        "invalid-argument",
        `Recovery entry ${index + 1} is invalid.`,
      );
    }

    if (entry.type === "medication") {
      const time = typeof entry.time === "string" ? entry.time.trim() : "";
      if (!time || time.length > 100) {
        throw new HttpsError(
          "invalid-argument",
          `Medication entry ${index + 1} has an invalid time.`,
        );
      }

      return {
        type: "medication",
        time,
        source: "patient-device-sync",
        syncedByUid: auth.uid,
      };
    }

    if (entry.type === "prompt") {
      const question =
        typeof entry.question === "string" ? entry.question.trim() : "";
      const response =
        typeof entry.response === "string" ? entry.response.trim() : "";

      if (!question || question.length > 500 || response.length > 2000) {
        throw new HttpsError(
          "invalid-argument",
          `Prompt entry ${index + 1} is invalid.`,
        );
      }

      return {
        type: "prompt",
        question,
        response,
        source: "patient-device-sync",
        syncedByUid: auth.uid,
      };
    }

    throw new HttpsError(
      "invalid-argument",
      `Recovery entry ${index + 1} has an unsupported type.`,
    );
  });

  const linkRef = db.doc(`patientLinks/${auth.uid}`);
  const linkSnapshot = await linkRef.get();

  if (!linkSnapshot.exists || linkSnapshot.data().permanent !== true) {
    throw new HttpsError(
      "failed-precondition",
      "This account is not linked to a recovery plan.",
    );
  }

  const link = linkSnapshot.data();
  const patientRef = db.doc(
    `clinics/${link.clinicId}/patients/${link.patientId}`,
  );
  const recoveryRef = patientRef.collection("recoveryDays").doc(dateKey);
  const now = Timestamp.now();
  const activityDate = Timestamp.fromDate(parsedDate);

  await db.runTransaction(async (transaction) => {
    const [patientSnapshot, currentRecovery] = await Promise.all([
      transaction.get(patientRef),
      transaction.get(recoveryRef),
    ]);

    if (!patientSnapshot.exists) {
      throw new HttpsError("not-found", "The linked recovery plan no longer exists.");
    }

    if (
      patientSnapshot.data().linkedPatientUid &&
      patientSnapshot.data().linkedPatientUid !== auth.uid
    ) {
      throw new HttpsError(
        "permission-denied",
        "This account is no longer linked to that recovery plan.",
      );
    }

    const existingEntries = currentRecovery.exists &&
        Array.isArray(currentRecovery.data().entries)
      ? currentRecovery.data().entries
      : [];

    const mergedEntries = [...existingEntries];
    for (const entry of sanitizedEntries) {
      const serialized = JSON.stringify(entry);
      const duplicate = mergedEntries.some(
        (existing) => JSON.stringify(existing) === serialized,
      );
      if (!duplicate) {
        mergedEntries.push(entry);
      }
    }

    if (mergedEntries.length > 500) {
      throw new HttpsError(
        "resource-exhausted",
        "This recovery day contains too many entries.",
      );
    }

    transaction.set(
      recoveryRef,
      {
        date: dateKey,
        entries: mergedEntries,
        updatedAt: now,
      },
      {merge: true},
    );

    const latestEntryDate = patientSnapshot.data().latestEntryDate;
    if (
      !(latestEntryDate instanceof Timestamp) ||
      latestEntryDate.toMillis() < activityDate.toMillis()
    ) {
      transaction.update(patientRef, {
        latestEntryDate: activityDate,
        updatedAt: now,
      });
    }
  });

  return {saved: sanitizedEntries.length, date: dateKey};
});
