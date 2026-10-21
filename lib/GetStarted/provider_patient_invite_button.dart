import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class ProviderPatientInviteButton extends StatefulWidget {
  final String clinicId;
  final String patientId;
  final String patientDisplayName;

  const ProviderPatientInviteButton({
    super.key,
    required this.clinicId,
    required this.patientId,
    required this.patientDisplayName,
  });

  @override
  State<ProviderPatientInviteButton> createState() =>
      _ProviderPatientInviteButtonState();
}

class _ProviderPatientInviteButtonState
    extends State<ProviderPatientInviteButton> {
  bool _sending = false;

  Future<void> _showInviteDialog() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Invite ${widget.patientDisplayName}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Patient account email',
                hintText: 'patient@example.com',
                border: OutlineInputBorder(),
                helperText:
                    'The invitation will appear when this email signs in.',
              ),
              validator: (value) {
                final normalized = value?.trim() ?? '';

                if (normalized.isEmpty) {
                  return 'Enter the patient email address.';
                }

                final atIndex = normalized.indexOf('@');
                final dotIndex = normalized.lastIndexOf('.');

                if (atIndex <= 0 || dotIndex <= atIndex + 1) {
                  return 'Enter a valid email address.';
                }

                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  emailController.text.trim(),
                );
              },
              icon: const Icon(Icons.send),
              label: const Text('Create Invite'),
            ),
          ],
        );
      },
    );

    emailController.dispose();

    if (email == null || email.isEmpty || !mounted) {
      return;
    }

    setState(() => _sending = true);

    try {
      final functions = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      );

      final callable = functions.httpsCallable('createPatientInvite');

      await callable.call<Map<String, dynamic>>(
        <String, dynamic>{
          'clinicId': widget.clinicId,
          'patientId': widget.patientId,
          'recipientEmail': email,
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Invitation created for $email. It will appear the next time that '
            'account opens NODE Recovery.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            error.message ?? 'Could not create the patient invitation.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Could not create the patient invitation: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _sending ? null : _showInviteDialog,
      icon: _sending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.mark_email_unread_outlined),
      label: Text(
        _sending ? 'Creating Invitation...' : 'Invite Patient to Their Plan',
      ),
    );
  }
}
