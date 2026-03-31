import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../HomePage/calendar_widg.dart';
import '../LoginComp/logic/provider/provider_cubit.dart';
import '../LoginComp/logic/provider/provider_state.dart';
import '../LoginComp/routing/routes.dart';

class ProviderMainScreen extends StatefulWidget {
  final String? clinicCode;

  const ProviderMainScreen({super.key, this.clinicCode});

  @override
  State<ProviderMainScreen> createState() => _ProviderMainScreenState();
}

class _ProviderMainScreenState extends State<ProviderMainScreen> {
  final GlobalKey<CalendarWidgetState> _calendarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
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
          // LEFT SIDE — USER LIST
          Expanded(
            flex: 3,
            child: BlocBuilder<ProviderCubit, ProviderState>(
              builder: (context, state) {
                final users = state.users;
                final selectedUser = state.selectedUser;

                if (state.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (users.isEmpty) {
                  return const Center(child: Text("No users found."));
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
                          ? Colors.blue.withValues(alpha: 0.15)
                          : Colors.transparent,
                      title: Text(
                        user.displayName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text("Device: ${user.deviceId}"),
                      onTap: () {
                        context.read<ProviderCubit>().selectUser(user);
                        if (user.latestEntryDate != null) {
                          _calendarKey.currentState?.focusOn(user.latestEntryDate!);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),

          // RIGHT SIDE — CALENDAR
          Expanded(
            flex: 6,
            child: BlocBuilder<ProviderCubit, ProviderState>(
              builder: (context, state) {
                final selectedUser = state.selectedUser;

                if (selectedUser == null) {
                  return const Center(
                    child: Text("Select a user to view their recovery calendar."),
                  );
                }

                // FORCE REFRESH: Key ensures CalendarWidget state is reset when user changes
                final keyString = 'provider_${selectedUser.id}_${state.demoMedications.length}_${state.demoPrompts.length}';

                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Viewing: ${selectedUser.displayName}",
                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              // FORCE CUBIT SOURCE: Pull arguments directly from state at click time
                              final currentState = context.read<ProviderCubit>().state;
                              Navigator.pushNamed(
                                context,
                                Routes.homeScreen,
                                arguments: {
                                  'medications': currentState.demoMedications,
                                  'prompts': currentState.demoPrompts,
                                },
                              );
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text("View Patient App"),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: CalendarWidget(
                        key: ValueKey(keyString),
                        prompts: state.demoPrompts,
                        medications: state.demoMedications,
                        StartDate: selectedUser.startDate ?? DateTime.now(),
                        externalFocusDay: selectedUser.latestEntryDate,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
