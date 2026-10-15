import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../LoginComp/core/widgets/MedicationEntryPage.dart';
import '../LoginComp/logic/provider/provider_cubit.dart';
import '../LoginComp/logic/provider/provider_state.dart';
import '../models/medication.dart';
import '../models/medication_schedule.dart';
import '../models/counseling_question.dart';
import '../models/prompt_schedule.dart';
import 'enter_counseling_data.dart';
import 'enter_medication_data.dart';

class ProviderProgramEditorScreen extends StatelessWidget {
  const ProviderProgramEditorScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProviderCubit, ProviderState>(
      builder: (context, state) {
        final patient = state.selectedUser;

        if (patient == null) {
          return const Scaffold(
            body: Center(
              child: Text('No patient is selected.'),
            ),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                '${patient.displayName} Program',
              ),
              bottom: const TabBar(
                tabs: [
                  Tab(
                    icon: Icon(Icons.medication),
                    text: 'Medications',
                  ),
                  Tab(
                    icon: Icon(Icons.question_answer),
                    text: 'Counseling',
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _MedicationList(
                  state: state,
                ),
                _PromptList(
                  state: state,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MedicationList extends StatelessWidget {
  final ProviderState state;

  const _MedicationList({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProviderCubit>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Medication'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: cubit,
                      child: const EnterPrescriptionData(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: state.selectedMedications.isEmpty
              ? const Center(
                  child: Text(
                    'No medications are configured.',
                  ),
                )
              : ListView.separated(
                  itemCount: state.selectedMedications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final medication = state.selectedMedications[index];
                    final startDate = medication.startDate ?? state.selectedUser?.startDate;

                    return ListTile(
                      key: medication.id == null ? null : ValueKey(medication.id),
                      title: Text(medication.name),
                      subtitle: Text(
                        '${medication.dose} | ${medication.times}\n'
                        'Start: ${startDate == null ? 'Not set' : MedicationSchedule.dateLabel(startDate)}'
                        ' | ${medication.numDays} days',
                      ),
                      onTap: state.saving ? null : () async {
                        final patientId = state.selectedUser?.id;
                        final updated = await Navigator.push<Medication>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MedicationEntryPage(
                              medication: medication,
                              otherMedications: [
                                for (var i = 0; i < state.selectedMedications.length; i++)
                                  if (i != index) state.selectedMedications[i],
                              ],
                              fallbackStartDate: state.selectedUser?.startDate,
                            ),
                          ),
                        );
                        if (!context.mounted || updated == null) return;
                        if (cubit.state.selectedUser?.id != patientId) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('The selected patient changed. Nothing was saved.'),
                          ));
                          return;
                        }
                        try {
                          await cubit.updateMedicationForSelectedUser(
                            updated.copyWith(id: medication.id),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Could not save medication: $error'),
                          ));
                        }
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: medication.id == null || state.saving
                            ? null
                            : () async {
                                try {
                                  await cubit.deleteMedicationFromSelectedUser(medication.id!);
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('Could not delete medication: $error'),
                                  ));
                                }
                              },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PromptList extends StatelessWidget {
  final ProviderState state;

  const _PromptList({required this.state});

  void _openForm(BuildContext context, [CounselingQuestion? prompt]) {
    final cubit = context.read<ProviderCubit>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: EnterCounselingPrompts(
            medications: state.selectedMedications,
            initialPrompt: prompt,
            // Existing legacy records use the patient's start, not today's date.
            fallbackStartDate: prompt == null ? null : state.selectedUser?.startDate,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProviderCubit>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Counseling Question'),
              onPressed: state.saving ? null : () => _openForm(context),
            ),
          ),
        ),
        Expanded(
          child: state.selectedPrompts.isEmpty
              ? const Center(child: Text('No counseling questions are configured.'))
              : ListView.separated(
                  itemCount: state.selectedPrompts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final prompt = state.selectedPrompts[index];
                    final canEdit = prompt.id != null && !state.saving;
                    return ListTile(
                      key: prompt.id == null ? null : ValueKey('prompt-${prompt.id}'),
                      title: Text(prompt.prompt),
                      subtitle: Text(
                        '${prompt.resReq}\n${PromptSchedule.rangeLabel(
                          prompt, fallbackStartDate: state.selectedUser?.startDate)}',
                      ),
                      onTap: canEdit ? () => _openForm(context, prompt) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit prompt',
                            icon: const Icon(Icons.edit),
                            onPressed: canEdit ? () => _openForm(context, prompt) : null,
                          ),
                          IconButton(
                            tooltip: 'Delete prompt',
                            icon: const Icon(Icons.delete),
                            onPressed: !canEdit ? null : () async {
                              try {
                                await cubit.deletePromptFromSelectedUser(prompt.id!);
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Could not delete prompt: $error'),
                                ));
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
