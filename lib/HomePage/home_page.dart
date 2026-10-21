import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../Bluetooth/bluetooth_trial.dart';
import '../LoginComp/logic/cubit/auth_cubit.dart';
import '../LoginComp/routing/routes.dart';
import '../Patient/patient_cubit.dart';
import '../Patient/patient_models.dart';
import 'calendar_widg.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BluetoothDevice? _selectedBluetoothDevice;
  bool _isBluetoothConnected = false;
  bool _dialogOpen = false;
  int _bluetoothRefreshToken = 0;
  String? _lastShownError;
  final Set<String> _shownInviteIds = <String>{};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreOrRequestBluetoothConnection());
    });
  }

  Future<void> _restoreOrRequestBluetoothConnection() async {
    try {
      final connectedDevices = await FlutterBluePlus.connectedDevices;

      if (!mounted) {
        return;
      }

      if (connectedDevices.isNotEmpty) {
        setState(() {
          _selectedBluetoothDevice = connectedDevices.first;
          _isBluetoothConnected = true;
          _bluetoothRefreshToken++;
        });
        return;
      }

      setState(() {
        _selectedBluetoothDevice = null;
        _isBluetoothConnected = false;
      });

      await _showBluetoothPurposeDialog();
    } catch (error, stackTrace) {
      debugPrint('PATIENT HOME: Bluetooth restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedBluetoothDevice = null;
        _isBluetoothConnected = false;
      });
    }
  }

  Future<void> _showBluetoothPurposeDialog() async {
    if (!mounted || _dialogOpen) {
      return;
    }

    _dialogOpen = true;

    final shouldConnect = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Connect to Your NODE Device'),
          content: const Text(
            'The patient connection only reads medication and recovery activity '
            'from NODE so your calendar can update. It cannot change or '
            'program your prescription.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Connect'),
            ),
          ],
        );
      },
    );

    _dialogOpen = false;

    if (shouldConnect == true && mounted) {
      await _openBluetoothScanner();
    }

    if (mounted) {
      _showNextInvite(context.read<PatientCubit>().state.pendingInvites);
    }
  }

  Future<void> _openBluetoothScanner() async {
    final device = await Navigator.push<BluetoothDevice>(
      context,
      MaterialPageRoute(
        builder: (_) => const BLEScannerWidget(),
      ),
    );

    if (!mounted || device == null) {
      return;
    }

    setState(() {
      _selectedBluetoothDevice = device;
      _isBluetoothConnected = true;
      _bluetoothRefreshToken++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(
          '${device.platformName.isEmpty ? 'NODE' : device.platformName} is '
          'connected for recovery-calendar syncing.',
        ),
      ),
    );
  }

  void _handlePatientState(BuildContext context, PatientState state) {
    final error = state.errorMessage;

    if (error == null) {
      _lastShownError = null;
    } else if (error != _lastShownError) {
      _lastShownError = error;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(error),
          ),
        );

        context.read<PatientCubit>().clearError();
      });
    }

    _showNextInvite(state.pendingInvites);
  }

  void _showNextInvite(List<PatientInvite> invites) {
    if (!mounted || _dialogOpen) {
      return;
    }

    PatientInvite? nextInvite;

    for (final invite in invites) {
      if (!_shownInviteIds.contains(invite.id)) {
        nextInvite = invite;
        break;
      }
    }

    if (nextInvite == null) {
      return;
    }

    _shownInviteIds.add(nextInvite.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dialogOpen) {
        _shownInviteIds.remove(nextInvite!.id);
        return;
      }

      unawaited(_presentInvite(nextInvite!));
    });
  }

  Future<void> _presentInvite(PatientInvite invite) async {
    _dialogOpen = true;

    final decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Recovery Plan Invitation'),
          content: Text(
            '${invite.providerEmail.isEmpty ? 'A provider' : invite.providerEmail} '
            'invited you to connect to the recovery plan for '
            '${invite.patientDisplayName}.\n\n'
            'Accepting permanently links this account to that plan so you and '
            'your provider can view the same calendar, medication activity, '
            'streaks, and tokens.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'later'),
              child: const Text('Not Now'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'decline'),
              child: const Text('Decline'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'accept'),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );

    _dialogOpen = false;

    if (!mounted || decision == null || decision == 'later') {
      return;
    }

    final cubit = context.read<PatientCubit>();

    try {
      if (decision == 'accept') {
        await cubit.acceptInvite(invite);

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'Your account is now linked to your NODE Recovery plan.',
            ),
          ),
        );
      } else if (decision == 'decline') {
        await cubit.declineInvite(invite);
      }
    } catch (_) {
      // PatientCubit exposes the useful Firebase error through PatientState.
    }

    if (mounted) {
      _showNextInvite(cubit.state.pendingInvites);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();

    return MultiBlocListener(
      listeners: [
        BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is UserSignedOut) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                Routes.loginScreen,
                (route) => false,
              );
            }
          },
        ),
        BlocListener<PatientCubit, PatientState>(
          listener: _handlePatientState,
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Recovery',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: _isBluetoothConnected
                  ? 'NODE connected for syncing'
                  : 'Connect NODE for syncing',
              color: _isBluetoothConnected ? Colors.blue : Colors.grey,
              icon: Icon(
                _isBluetoothConnected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_searching,
              ),
              onPressed: _openBluetoothScanner,
            ),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthCubit>().signOut(),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h),
            child: BlocBuilder<PatientCubit, PatientState>(
              builder: (context, state) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/NodeLogo.png',
                          height: 58.h,
                          width: 110.w,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName == null || displayName.isEmpty
                                    ? 'Welcome to NODE Recovery'
                                    : 'Welcome, $displayName',
                                style: TextStyle(
                                  fontSize: 19.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                user?.email ?? '',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    _buildConnectionCard(),
                    SizedBox(height: 8.h),
                    Expanded(
                      child: _buildPatientContent(state),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    final deviceName = _selectedBluetoothDevice?.platformName.trim();
    final connectedName =
        deviceName == null || deviceName.isEmpty ? 'NODE device' : deviceName;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openBluetoothScanner,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: _isBluetoothConnected
              ? Colors.green.withValues(alpha: 0.12)
              : Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isBluetoothConnected ? Colors.green : Colors.orange,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isBluetoothConnected ? Icons.sync : Icons.sync_problem_outlined,
              color: _isBluetoothConnected ? Colors.green : Colors.orange,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                _isBluetoothConnected
                    ? '$connectedName is connected. Medication activity will '
                        'sync into this calendar.'
                    : 'NODE is not connected. Tap here to connect and import '
                        'medication activity. Patient mode cannot program NODE.',
                style: TextStyle(fontSize: 12.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientContent(PatientState state) {
    if (state.loading && state.link == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.link == null) {
      return Center(
        child: SingleChildScrollView(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 52.sp,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No Recovery Plan Is Linked Yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Ask your provider to invite '
                    '${FirebaseAuth.instance.currentUser?.email ?? 'this account email'}. '
                    'The invitation will appear here the next time you sign in.',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 14.h),
                  OutlinedButton.icon(
                    onPressed: state.saving
                        ? null
                        : () => context.read<PatientCubit>().refreshInvites(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check for Invitations'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final profile = state.profile;

    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return CalendarWidget(
      key: ValueKey(
        'patient:${state.link!.clinicId}:${state.link!.patientId}',
      ),
      dataOwnerId: profile.id,
      prompts: state.prompts,
      medications: state.medications,
      StartDate: profile.startDate ?? DateTime.now(),
      externalFocusDay: profile.latestEntryDate,
      externalRecoveryProgress: state.recoveryMap,
      bluetoothRefreshToken: _bluetoothRefreshToken,
      useLocalRecoveryCache: true,
      showProgramActions: false,
      onRecoveryProgressReceived: (date, entries) {
        return context.read<PatientCubit>().saveRecoveryProgress(
              date: date,
              entries: entries,
            );
      },
    );
  }
}
