import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'summary_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../LoginComp/logic/provider/provider_cubit.dart';
import '../LoginComp/theming/styles.dart';
import '../LoginComp/theming/colors.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/medication.dart';
import '../models/counseling_question.dart';
import '../models/medication_schedule.dart';
import '../models/prompt_schedule.dart';

class EnterCounselingPrompts extends StatefulWidget {
  final List<Medication> medications;
  final BluetoothDevice? device;
  final CounselingQuestion? initialPrompt;
  final DateTime? fallbackStartDate;
  // Used when editing a local draft: return a value, never write to Firestore.
  final bool returnResultOnly;

  const EnterCounselingPrompts({
    super.key,
    required this.medications,
    this.device,
    this.initialPrompt,
    this.fallbackStartDate,
    this.returnResultOnly = false,
  });

  @override
  _EnterCounselingPrompts createState() => _EnterCounselingPrompts();
}

class _EnterCounselingPrompts extends State<EnterCounselingPrompts> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _streakTitleController = TextEditingController();
  final TextEditingController _streakThresholdController =
      TextEditingController();
  final TextEditingController _tokenTitleController = TextEditingController();
  final TextEditingController _tokenThresholdController =
      TextEditingController();
  final TextEditingController _tokenQuantityController =
      TextEditingController(text: '1');

  bool _streakEnabled = false;
  bool _tokenEnabled = false;

  String _streakOperator = '<';
  String _tokenOperator = '<';

  String _streakYesNoThreshold = 'Yes';
  String _tokenYesNoThreshold = 'Yes';

  String _responseRequired = 'Require a Response?';
  String? _responseType;
  List<CounselingQuestion> prompts = [];
  String? _errorMessage;
  late DateTime _startDate;
  ProviderCubit? _providerCubit;
  String? _patientAtOpen;
  bool _saving = false;
  bool _responseChanged = false;
  bool _streakThresholdChanged = false;
  bool _tokenThresholdChanged = false;

  bool get _editing => widget.initialPrompt != null;

  @override
  void initState() {
    super.initState();
    if (!widget.returnResultOnly) {
      try {
        _providerCubit = context.read<ProviderCubit>();
        _patientAtOpen = _providerCubit?.state.selectedUser?.id;
      } catch (_) {
        // Standalone setup does not have a provider cubit.
      }
    }
    final original = widget.initialPrompt;
    _startDate = DateUtils.dateOnly(original == null
        ? (widget.fallbackStartDate ?? DateTime.now())
        : (original.startDate ??
            widget.fallbackStartDate ??
            _providerCubit?.state.selectedUser?.startDate ??
            DateTime.now()));
    if (original == null) return;

    _promptController.text = original.prompt;
    _daysController.text = original.numberOfDays.toString();
    _streakEnabled = original.streakEnabled;
    _streakTitleController.text = original.streakTitle;
    _tokenEnabled = original.tokenEnabled;
    _tokenTitleController.text = original.tokenTitle;
    _tokenQuantityController.text =
        original.tokenQuantity > 0 ? original.tokenQuantity.toString() : '1';

    final responseRequirement = original.resReq.trim().toLowerCase();
    final options =
        original.options.map((v) => v.trim().toLowerCase()).join(',');
    if (responseRequirement == 'yes_no' ||
        (responseRequirement == 'yes' && options == 'yes,no')) {
      _responseRequired = 'Yes';
      _responseType = 'Yes/No';
    } else if (responseRequirement == 'number' ||
        (responseRequirement == 'yes' && options == '1,2,3,4,5,6,7,8,9,10')) {
      _responseRequired = 'Yes';
      _responseType = '1-10 Scale';
    } else if (responseRequirement == 'journal response') {
      _responseRequired = 'Journal Response';
    } else {
      // Preserve legacy/custom response options unless explicitly changed.
      _responseRequired = 'Keep existing response';
    }
    _loadThreshold(original.streakThreshold, streak: true);
    _loadThreshold(original.tokenThreshold, streak: false);
  }

  void _loadThreshold(String value, {required bool streak}) {
    final match = RegExp(r'^(<=|>=|<|>|=)?\s*(\d+)$').firstMatch(value.trim());
    final operator = match?.group(1) ?? '=';
    final number = match?.group(2) ?? '';
    final yesNo = value.trim().replaceFirst(RegExp(r'^=\s*'), '').toLowerCase();
    if (streak) {
      _streakOperator = operator;
      _streakThresholdController.text = number;
      _streakYesNoThreshold = yesNo == 'no' ? 'No' : 'Yes';
    } else {
      _tokenOperator = operator;
      _tokenThresholdController.text = number;
      _tokenYesNoThreshold = yesNo == 'no' ? 'No' : 'Yes';
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(_startDate.year < 2000 ? _startDate.year : 2000),
      lastDate:
          DateTime(_startDate.year > 2100 ? _startDate.year : 2100, 12, 31),
    );
    if (!mounted || picked == null) return;
    setState(() => _startDate = DateUtils.dateOnly(picked));
  }

  Future<void> _editDraft(int index) async {
    final original = prompts[index];
    final updated = await Navigator.push<CounselingQuestion>(
      context,
      MaterialPageRoute(
          builder: (_) => EnterCounselingPrompts(
                medications: widget.medications,
                device: widget.device,
                initialPrompt: original,
                fallbackStartDate: _startDate,
                returnResultOnly: true,
              )),
    );
    if (!mounted || updated == null) return;
    final currentIndex = prompts.indexOf(original);
    if (currentIndex >= 0) setState(() => prompts[currentIndex] = updated);
  }

  Future<void> _addPrompt() async {
    if (_saving) return;
    final promptText = _promptController.text.trim();
    final numberOfDays = int.tryParse(_daysController.text.trim());

    if (promptText.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a counseling prompt.';
      });
      return;
    }

    if (_responseRequired == 'Require a Response?') {
      setState(() {
        _errorMessage = 'Select whether a response is required.';
      });
      return;
    }

    if (_responseRequired == 'Yes' && _responseType == null) {
      setState(() {
        _errorMessage = 'Select a response type: Yes/No or 1-10 Scale.';
      });
      return;
    }

    if (numberOfDays == null || numberOfDays <= 0) {
      setState(() {
        _errorMessage = 'Enter a valid number of days.';
      });
      return;
    }

    final streakError = _validateReward(
      rewardName: 'streak',
      enabled: _streakEnabled,
      titleController: _streakTitleController,
      numericThresholdController: _streakThresholdController,
    );

    if (streakError != null) {
      setState(() {
        _errorMessage = streakError;
      });
      return;
    }

    final tokenError = _validateReward(
      rewardName: 'token reward',
      enabled: _tokenEnabled,
      titleController: _tokenTitleController,
      numericThresholdController: _tokenThresholdController,
      quantityController: _tokenQuantityController,
    );

    if (tokenError != null) {
      setState(() {
        _errorMessage = tokenError;
      });
      return;
    }

    final List<String> options;

    if (_responseRequired == 'Keep existing response') {
      options = List<String>.of(widget.initialPrompt!.options);
    } else if (_responseRequired == 'Yes' && _responseType == 'Yes/No') {
      options = ['Yes', 'No'];
    } else if (_responseRequired == 'Yes' && _responseType == '1-10 Scale') {
      options = List.generate(
        10,
        (index) => (index + 1).toString(),
      );
    } else {
      options = ['Respond in Journal'];
    }

    final streakThreshold = _buildThreshold(
      operatorValue: _streakOperator,
      numericController: _streakThresholdController,
      yesNoThreshold: _streakYesNoThreshold,
    );

    final tokenThreshold = _buildThreshold(
      operatorValue: _tokenOperator,
      numericController: _tokenThresholdController,
      yesNoThreshold: _tokenYesNoThreshold,
    );

    final original = widget.initialPrompt;
    final keepResponse = original != null &&
        (!_responseChanged || _responseRequired == 'Keep existing response');
    final newPrompt = CounselingQuestion(
      id: original?.id,
      prompt: promptText,
      resReq: keepResponse ? original!.resReq : _responseRequired,
      options: keepResponse ? List<String>.of(original!.options) : options,
      numberOfDays: numberOfDays,
      startDate: _startDate,
      streakEnabled: _streakEnabled,
      streakTitle: _streakTitleController.text.trim(),
      streakThreshold: _streakEnabled
          ? (keepResponse && !_streakThresholdChanged && original!.streakEnabled
              ? original!.streakThreshold
              : streakThreshold)
          : (original?.streakThreshold ?? 'None'),
      tokenEnabled: _tokenEnabled,
      tokenTitle: _tokenTitleController.text.trim(),
      tokenThreshold: _tokenEnabled
          ? (keepResponse && !_tokenThresholdChanged && original!.tokenEnabled
              ? original!.tokenThreshold
              : tokenThreshold)
          : (original?.tokenThreshold ?? 'None'),
      tokenQuantity: _tokenEnabled
          ? int.parse(_tokenQuantityController.text.trim())
          : (original?.tokenQuantity ?? 0),
    );

    try {
      PromptSchedule.validateEntry(newPrompt);
    } on MedicationScheduleException catch (error) {
      setState(() => _errorMessage = error.message);
      return;
    }
    if (widget.returnResultOnly) {
      Navigator.pop(context, newPrompt);
      return;
    }
    final providerCubit = _providerCubit;
    if (providerCubit != null) {
      if (_patientAtOpen == null ||
          providerCubit.state.selectedUser?.id != _patientAtOpen) {
        setState(() => _errorMessage =
            'The selected patient changed. Close this form and open it again.');
        return;
      }
      setState(() => _saving = true);
      try {
        debugPrint(
          'PROVIDER PROMPT FORM: '
          'Saving "${newPrompt.prompt}"',
        );

        if (_editing) {
          await providerCubit.updatePromptForSelectedUser(newPrompt);
        } else {
          await providerCubit.addPromptToSelectedUser(newPrompt);
        }

        debugPrint(
          'PROVIDER PROMPT FORM: Save completed',
        );

        if (!mounted) {
          return;
        }

        Navigator.pop(context);
      } catch (error, stackTrace) {
        debugPrint(
          'PROVIDER PROMPT FORM ERROR: $error',
        );
        debugPrintStack(stackTrace: stackTrace);

        if (!mounted) {
          return;
        }

        setState(() {
          _errorMessage = 'Could not save prompt: $error';
        });
      } finally {
        if (mounted) setState(() => _saving = false);
      }

      return;
    }
    if (_editing) {
      Navigator.pop(context, newPrompt);
      return;
    }

    setState(() {
      prompts.add(newPrompt);

      _promptController.clear();
      _daysController.clear();
      _responseChanged = false;
      _streakThresholdChanged = false;
      _tokenThresholdChanged = false;

      _responseRequired = 'Require a Response?';
      _responseType = null;

      _streakEnabled = false;
      _streakTitleController.clear();
      _streakThresholdController.clear();
      _streakOperator = '<';
      _streakYesNoThreshold = 'Yes';

      _tokenEnabled = false;
      _tokenTitleController.clear();
      _tokenThresholdController.clear();
      _tokenQuantityController.text = '1';
      _tokenOperator = '<';
      _tokenYesNoThreshold = 'Yes';

      _errorMessage = null;
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _daysController.dispose();

    _streakTitleController.dispose();
    _streakThresholdController.dispose();

    _tokenTitleController.dispose();
    _tokenThresholdController.dispose();
    _tokenQuantityController.dispose();

    super.dispose();
  }

  Widget _buildPromptRewardSection({
    required String rewardName,
    required bool enabled,
    required ValueChanged<bool> onEnabledChanged,
    required TextEditingController titleController,
    required String operatorValue,
    required ValueChanged<String?> onOperatorChanged,
    required TextEditingController numericThresholdController,
    required String yesNoThreshold,
    required ValueChanged<String?> onYesNoChanged,
    TextEditingController? quantityController,
    required VoidCallback onThresholdChanged,
  }) {
    final isToken = quantityController != null;

    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Add a $rewardName?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              value: enabled,
              onChanged: onEnabledChanged,
            ),
            if (enabled) ...[
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: isToken ? 'Token Title' : 'Streak Title',
                  hintText:
                      isToken ? 'Example: Staying Calm' : 'Example: Low Stress',
                  border: const OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              if (_responseRequired == 'Yes' && _responseType == '1-10 Scale')
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110.w,
                      child: DropdownButtonFormField<String>(
                        value: operatorValue,
                        decoration: const InputDecoration(
                          labelText: 'Compare',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          '<',
                          '>',
                          '=',
                          '<=',
                          '>=',
                        ].map((operator) {
                          return DropdownMenuItem<String>(
                            value: operator,
                            child: Text(operator),
                          );
                        }).toList(),
                        onChanged: onOperatorChanged,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: TextField(
                        controller: numericThresholdController,
                        onChanged: (_) => onThresholdChanged(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Threshold Value',
                          hintText: '1-10',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                )
              else if (_responseRequired == 'Yes' && _responseType == 'Yes/No')
                DropdownButtonFormField<String>(
                  value: yesNoThreshold,
                  decoration: const InputDecoration(
                    labelText: 'Response Required for Reward',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Yes',
                      child: Text('Yes'),
                    ),
                    DropdownMenuItem(
                      value: 'No',
                      child: Text('No'),
                    ),
                  ],
                  onChanged: onYesNoChanged,
                )
              else if (_responseRequired == 'Journal Response')
                const InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Threshold',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    'None — reward when the journal response is submitted',
                  ),
                )
              else if (_responseRequired == 'Keep existing response')
                const Text(
                    'The existing response options and thresholds are retained.')
              else
                const Text(
                  'Select the required response and response type above.',
                  style: TextStyle(color: Colors.orange),
                ),
              if (isToken) ...[
                SizedBox(height: 12.h),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Number of Tokens',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _buildThreshold({
    required String operatorValue,
    required TextEditingController numericController,
    required String yesNoThreshold,
  }) {
    if (_responseRequired == 'Journal Response') {
      return 'None';
    }

    if (_responseRequired == 'Yes' && _responseType == 'Yes/No') {
      // The demo format uses "Threshold: No", rather than "=No".
      return yesNoThreshold;
    }

    if (_responseRequired == 'Yes' && _responseType == '1-10 Scale') {
      return '$operatorValue${numericController.text.trim()}';
    }

    return 'None';
  }

  String? _validateReward({
    required String rewardName,
    required bool enabled,
    required TextEditingController titleController,
    required TextEditingController numericThresholdController,
    TextEditingController? quantityController,
  }) {
    if (!enabled) {
      return null;
    }

    if (titleController.text.trim().isEmpty) {
      return 'Enter a title for the $rewardName.';
    }

    if (_responseRequired == 'Yes' && _responseType == '1-10 Scale') {
      final threshold = int.tryParse(numericThresholdController.text.trim());

      if (threshold == null || threshold < 1 || threshold > 10) {
        return 'Enter a $rewardName threshold from 1 through 10.';
      }
    }

    if (quantityController != null) {
      final quantity = int.tryParse(quantityController.text.trim());

      if (quantity == null || quantity <= 0) {
        return 'Enter a token quantity greater than zero.';
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isProvider = _providerCubit != null;

    return Scaffold(
      appBar: AppBar(
          title: Text(_editing
              ? 'Edit Counseling Prompt'
              : 'Enter Counseling Prompts')),
      resizeToAvoidBottomInset: true,
      body: AbsorbPointer(
        absorbing: _saving,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  key: const ValueKey('prompt-text'),
                  controller: _promptController,
                  decoration: InputDecoration(
                    labelText: "Enter Prompt Here",
                    labelStyle: TextStyles.font14Hint500Weight,
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[400]!)),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 1.5),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: ColorsManager.mainBlue, width: 2.0),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _responseRequired,
                        items: [
                          'Require a Response?',
                          'Yes',
                          'Journal Response',
                          if (_editing) 'Keep existing response',
                        ].map((resReq) {
                          return DropdownMenuItem<String>(
                              value: resReq, child: Text(resReq));
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _responseRequired = value;
                            _responseChanged = true;

                            if (_responseRequired != 'Yes') {
                              _responseType = null;
                            }

                            _errorMessage = null;
                          });
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[400]!)),
                          enabledBorder: const OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.black, width: 1.5),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                                color: ColorsManager.mainBlue, width: 2.0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                if (_responseRequired == 'Yes') ...[
                  const Text(
                    "Select Response Type:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  RadioListTile<String>(
                    title: const Text('Yes/No'),
                    value: 'Yes/No',
                    groupValue: _responseType,
                    onChanged: (value) {
                      setState(() {
                        _responseType = value;
                        _responseChanged = true;
                        _errorMessage = null;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('1-10 Scale'),
                    value: '1-10 Scale',
                    groupValue: _responseType,
                    onChanged: (value) {
                      setState(() {
                        _responseType = value;
                        _responseChanged = true;
                        _errorMessage = null;
                      });
                    },
                  ),
                ],
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red, fontSize: 12.sp),
                    ),
                  ),
                SizedBox(height: 10.h),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  key: const ValueKey('prompt-start'),
                  title: const Text('Start Date'),
                  subtitle: Text(MedicationSchedule.dateLabel(_startDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _saving ? null : _pickStartDate,
                ),
                TextField(
                  key: const ValueKey('prompt-days'),
                  controller: _daysController,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: "Number of Days",
                    helperText: PromptSchedule.dateRangeLabel(
                        _startDate, int.tryParse(_daysController.text.trim())),
                    helperMaxLines: 2,
                    labelStyle: TextStyles.font14Hint500Weight,
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[400]!)),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 1.5),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: ColorsManager.mainBlue, width: 2.0),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                _buildPromptRewardSection(
                  rewardName: 'streak',
                  onThresholdChanged: () => _streakThresholdChanged = true,
                  enabled: _streakEnabled,
                  onEnabledChanged: (value) {
                    setState(() {
                      _streakEnabled = value;
                    });
                  },
                  titleController: _streakTitleController,
                  operatorValue: _streakOperator,
                  onOperatorChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _streakOperator = value;
                      _streakThresholdChanged = true;
                    });
                  },
                  numericThresholdController: _streakThresholdController,
                  yesNoThreshold: _streakYesNoThreshold,
                  onYesNoChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _streakYesNoThreshold = value;
                      _streakThresholdChanged = true;
                    });
                  },
                ),
                _buildPromptRewardSection(
                  rewardName: 'token reward',
                  onThresholdChanged: () => _tokenThresholdChanged = true,
                  enabled: _tokenEnabled,
                  onEnabledChanged: (value) {
                    setState(() {
                      _tokenEnabled = value;
                    });
                  },
                  titleController: _tokenTitleController,
                  operatorValue: _tokenOperator,
                  onOperatorChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _tokenOperator = value;
                      _tokenThresholdChanged = true;
                    });
                  },
                  numericThresholdController: _tokenThresholdController,
                  yesNoThreshold: _tokenYesNoThreshold,
                  onYesNoChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _tokenYesNoThreshold = value;
                      _tokenThresholdChanged = true;
                    });
                  },
                  quantityController: _tokenQuantityController,
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('prompt-save'),
                    onPressed: _saving ? null : _addPrompt,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 15.h),
                      backgroundColor: ColorsManager.mainBlue,
                    ),
                    child: Text(
                      _saving
                          ? 'Saving...'
                          : _editing
                              ? 'Save Changes'
                              : isProvider
                                  ? 'Save Prompt'
                                  : 'Add Prompt',
                      style: TextStyles.font14Hint500Weight
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Dates are saved in the app. Bluetooth sends only prompts active '
                    'today, with their remaining days. Reprogram NODE when a future '
                    'prompt starts; editing the app does not update an offline device.',
                  ),
                ),
                if (!isProvider && !_editing && !widget.returnResultOnly) ...[
                  SizedBox(height: 20.h),
                  SizedBox(
                    height: 200.h,
                    child: ListView.builder(
                      itemCount: prompts.length,
                      itemBuilder: (context, index) {
                        final prompt = prompts[index];
                        return ListTile(
                          title: Text(
                              "${prompt.prompt} (${prompt.numberOfDays} day(s))"),
                          subtitle: Text(PromptSchedule.rangeLabel(prompt)),
                          leading: const Icon(Icons.edit),
                          onTap: () => _editDraft(index),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                prompts.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ), // AbsorbPointer
      bottomNavigationBar: isProvider || _editing || widget.returnResultOnly
          ? null
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    debugPrint(
                      'TRACE 5 COUNSELING DATA -> SUMMARY: ${widget.device?.remoteId}',
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecoverySummaryScreen(
                          prompts: prompts,
                          medications: widget.medications,
                          device: widget.device,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15.h),
                  ),
                  child: Text(
                    "Continue",
                    style: TextStyles.font14Hint500Weight
                        .copyWith(color: ColorsManager.mainBlue),
                  ),
                ),
              ),
            ),
    );
  }
}
