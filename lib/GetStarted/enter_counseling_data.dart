import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'summary_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../LoginComp/logic/provider/provider_cubit.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/medication.dart';
import '../models/counseling_question.dart';

class EnterCounselingPrompts extends StatefulWidget {
  final List<Medication> medications;
  final BluetoothDevice? device;

  const EnterCounselingPrompts(
      {super.key, required this.medications, this.device});

  @override
  _EnterCounselingPrompts createState() => _EnterCounselingPrompts();
}

class _EnterCounselingPrompts extends State<EnterCounselingPrompts> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _streakTitleController = TextEditingController();
  final TextEditingController _streakThresholdController = TextEditingController();
  final TextEditingController _tokenTitleController = TextEditingController();
  final TextEditingController _tokenThresholdController = TextEditingController();
  final TextEditingController _tokenQuantityController = TextEditingController(text: '1');

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

    void _addPrompt() {
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
        _errorMessage =
            'Select a response type: Yes/No or 1-10 Scale.';
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

    if (_responseRequired == 'Yes' &&
        _responseType == 'Yes/No') {
      options = ['Yes', 'No'];
    } else if (_responseRequired == 'Yes' &&
        _responseType == '1-10 Scale') {
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

    final newPrompt = CounselingQuestion(
      prompt: promptText,
      resReq: _responseRequired,
      options: options,
      numberOfDays: numberOfDays,

      streakEnabled: _streakEnabled,
      streakTitle: _streakEnabled
          ? _streakTitleController.text.trim()
          : '',
      streakThreshold:
          _streakEnabled ? streakThreshold : 'None',

      tokenEnabled: _tokenEnabled,
      tokenTitle:
          _tokenEnabled ? _tokenTitleController.text.trim() : '',
      tokenThreshold:
          _tokenEnabled ? tokenThreshold : 'None',
      tokenQuantity: _tokenEnabled
          ? int.parse(_tokenQuantityController.text.trim())
          : 0,
    );

    ProviderCubit? providerCubit;

    try {
      providerCubit = context.read<ProviderCubit>();
    } catch (_) {
      providerCubit = null;
    }

    if (providerCubit != null) {
      providerCubit.addPromptToSelectedUser(newPrompt);
      Navigator.pop(context);
      return;
    }

    setState(() {
      prompts.add(newPrompt);

      _promptController.clear();
      _daysController.clear();

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
                  hintText: isToken
                      ? 'Example: Staying Calm'
                      : 'Example: Low Stress',
                  border: const OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),

              if (_responseRequired == 'Yes' &&
                  _responseType == '1-10 Scale')
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
              else if (_responseRequired == 'Yes' &&
                  _responseType == 'Yes/No')
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

    if (_responseRequired == 'Yes' &&
        _responseType == 'Yes/No') {
      // The demo format uses "Threshold: No", rather than "=No".
      return yesNoThreshold;
    }

    if (_responseRequired == 'Yes' &&
        _responseType == '1-10 Scale') {
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

    if (_responseRequired == 'Yes' &&
        _responseType == '1-10 Scale') {
      final threshold =
          int.tryParse(numericThresholdController.text.trim());

      if (threshold == null || threshold < 1 || threshold > 10) {
        return 'Enter a $rewardName threshold from 1 through 10.';
      }
    }

    if (quantityController != null) {
      final quantity =
          int.tryParse(quantityController.text.trim());

      if (quantity == null || quantity <= 0) {
        return 'Enter a token quantity greater than zero.';
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    bool isProvider = false;
    try {
      isProvider = context.read<ProviderCubit>().state.selectedUser != null;
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(title: const Text("Enter Counseling Prompts")),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
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
                      items: ['Require a Response?', 'Yes', 'Journal Response']
                          .map((resReq) {
                        return DropdownMenuItem<String>(
                            value: resReq, child: Text(resReq));
                      }).toList(),
                                              onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _responseRequired = value;

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
              TextField(
                controller: _daysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Number of Days",
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
                  });
                },
                numericThresholdController:
                    _streakThresholdController,
                yesNoThreshold: _streakYesNoThreshold,
                onYesNoChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _streakYesNoThreshold = value;
                  });
                },
              ),

              _buildPromptRewardSection(
                rewardName: 'token reward',
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
                  });
                },
                numericThresholdController:
                    _tokenThresholdController,
                yesNoThreshold: _tokenYesNoThreshold,
                onYesNoChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _tokenYesNoThreshold = value;
                  });
                },
                quantityController: _tokenQuantityController,
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addPrompt,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15.h),
                    backgroundColor: ColorsManager.mainBlue,
                  ),
                  child: Text(
                    isProvider ? "Save Prompt" : "Add Prompt",
                    style: TextStyles.font14Hint500Weight
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),
              if (!isProvider) ...[
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
                        subtitle: Text("Response: ${prompt.resReq}"),
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
      bottomNavigationBar: isProvider
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
