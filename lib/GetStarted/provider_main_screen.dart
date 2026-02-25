import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../HomePage/calendar_widg.dart';
import '../LoginComp/logic/provider/provider_cubit.dart';
import '../LoginComp/logic/provider/provider_state.dart';

class ProviderMainScreen extends StatefulWidget {
  final String? clinicCode;

  const ProviderMainScreen({super.key, this.clinicCode});

  @override
  State<ProviderMainScreen> createState() => _ProviderMainScreenState();
}

class _ProviderMainScreenState extends State<ProviderMainScreen> {
  // Key to control the calendar widget
  final GlobalKey<CalendarWidgetState> _calendarKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Load provider data for this clinic
    context.read<ProviderCubit>().loadClinicData(widget.clinicCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Provider Dashboard",
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
      ),

      body: Row(
        children: [
          // ----------------------------------------------------------
          // LEFT SIDE — USER/DEVICE LIST
          // ----------------------------------------------------------
          Expanded(
            flex: 3,
            child: BlocBuilder<ProviderCubit, ProviderState>(
              builder: (context, state) {
                final users = state.users; // list of provider's users
                final selectedUser = state.selectedUser;

                if (state.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (users.isEmpty) {
                  return const Center(
                    child: Text("No users found for this clinic."),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.all(12.w),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final user = users[i];
                    final isSelected = selectedUser?.id == user.id;

                    return ListTile(
                      tileColor: isSelected
                          ? Colors.blue.withOpacity(0.15)
                          : Colors.transparent,
                      title: Text(
                        user.displayName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text("Device: ${user.deviceId}"),
                      onTap: () {
                        context.read<ProviderCubit>().selectUser(user);

                        // Focus calendar on the user's most recent recovery entry
                        if (user.latestEntryDate != null) {
                          _calendarKey.currentState
                              ?.focusOn(user.latestEntryDate!);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),

          // ----------------------------------------------------------
          // RIGHT SIDE — CALENDAR
          // ----------------------------------------------------------
          Expanded(
            flex: 6,
            child: BlocBuilder<ProviderCubit, ProviderState>(
              builder: (context, state) {
                final selectedUser = state.selectedUser;

                if (selectedUser == null) {
                  return const Center(
                    child: Text(
                      "Select a user to view their recovery calendar.",
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                return CalendarWidget(
                  key: _calendarKey,

                  // Provider does NOT use user prompts/medications
                  prompts: const [],
                  medications: const [],

                  // Start date for the calendar (use user's first entry or today)
                  StartDate: selectedUser.startDate ?? DateTime.now(),

                  // Inject recovery progress from ProviderCubit
                  externalRecoveryProgress: state.recoveryMap,

                  // Focus calendar on selected user's most recent entry
                  externalFocusDay: selectedUser.latestEntryDate,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}