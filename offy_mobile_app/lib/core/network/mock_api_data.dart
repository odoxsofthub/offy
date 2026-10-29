import '../constants/api_constants.dart';

class MockApiData {
  static bool isLoggedIn = true;

  static const expenseSummaryResponse = {
    "success": true,
    "message": "Expense summary fetched successfully",
    "data": {
      "pending_reimbursement_amount": 0.0,
      "pending_reimbursement_display": "\$0.00",
      "pending_count": 0,
      "average_approval_time": {
        "value": 2,
        "unit": "business_days",
        "display": "2 business days",
        "source": "default",
      },
      "recent_expenses": [
        {
          "id": 5,
          "title": "Test recent meal expense",
          "category": "Communication",
          "date": "2026-07-06",
          "amount": 24.5,
          "amount_display": "(\$24.50)",
          "currency": "USD",
          "status": "draft",
          "status_display": "Draft",
          "icon": "receipt",
          "has_receipt": false,
        },
        {
          "id": 6,
          "title": "Test recent travel expense",
          "category": "Expenses",
          "date": "2026-07-05",
          "amount": 18.75,
          "amount_display": "(\$18.75)",
          "currency": "USD",
          "status": "draft",
          "status_display": "Draft",
          "icon": "receipt",
          "has_receipt": false,
        },
      ],
    },
  };
  static Map<String, dynamic> getMockResponse(String method, String endpoint) {
    if (method == 'DELETE' && endpoint.contains(ApiConstants.notifications)) {
      return {
        "success": true,
        "message": "Notification dismissed successfully",
        "data": null,
      };
    }

    if (endpoint.contains(ApiConstants.notifications)) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      String todayAt(int hour, int minute) =>
          '${today.toIso8601String().substring(0, 10)}T${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
      String yesterdayAt(int hour, int minute) =>
          '${yesterday.toIso8601String().substring(0, 10)}T${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';

      return {
        "success": true,
        "message": "Notifications fetched successfully",
        "data": {
          "unread_count_before_fetch": 3,
          "notifications": [
            {
              "id": 1,
              "type": "expense_approved",
              "title": "Expense Approved",
              "message":
                  "Your trip to Singapore claim (#EXP-2401) has been approved.",
              "is_read": false,
              "data": {},
              "created_at": todayAt(8, 30),
            },
            {
              "id": 2,
              "type": "timeoff_approved",
              "title": "Leave Approved",
              "message":
                  "Your Annual Leave request for Aug 15-20 has been approved by HR.",
              "is_read": false,
              "data": {},
              "created_at": todayAt(9, 15),
            },
            {
              "id": 3,
              "type": "expense_rejected",
              "title": "Expense Rejected",
              "message":
                  "Client gift basket (#EXP-2388) was rejected. Please resubmit with itemized receipts.",
              "is_read": false,
              "data": {},
              "created_at": todayAt(11, 0),
            },
            {
              "id": 4,
              "type": "payslip_available",
              "title": "Payslip Available",
              "message":
                  "Your payslip for July 2026 is now ready. Tap to view and download.",
              "is_read": true,
              "data": {},
              "created_at": yesterdayAt(7, 0),
            },
            {
              "id": 5,
              "type": "leave_reminder",
              "title": "Leave Reminder",
              "message":
                  "You have 14.5 days of Annual Leave remaining. Plan your time off before year-end.",
              "is_read": true,
              "data": {},
              "created_at": yesterdayAt(10, 30),
            },
            {
              "id": 6,
              "type": "announcement",
              "title": "Company Announcement",
              "message":
                  "Office will be closed on Aug 15 for Independence Day. Enjoy the long weekend!",
              "is_read": true,
              "data": {},
              "created_at": yesterdayAt(14, 0),
            },
          ],
          "pagination": {"page": 1, "limit": 20, "total": 6, "has_next": false},
        },
      };
    }

    if (endpoint.contains(ApiConstants.privacyPolicy)) {
      return {
        "success": true,
        "message": "Privacy policy fetched successfully",
        "data": {
          "privacy_policy": {
            "id": 1,
            "title": "Privacy Policy",
            "body": """
              <h3>1. Introduction</h3>
              <p>Welcome to our application. This User Policy outlines our commitment to protecting your privacy and managing your personal data responsibly.</p>
              <h3>2. Data Collection</h3>
              <p>We collect essential information to facilitate HR management, attendance tracking, payslip distribution, and leave requests.</p>
              <h3>3. Data Security</h3>
              <p>All transmitted information is encrypted using industry-standard protocols. Access is restricted to authorized personnel only.</p>
              <h3>4. User Rights</h3>
              <p>You have the right to review, update, or request the removal of personal details in accordance with applicable laws.</p>
            """,
            "is_published": true,
            "updated_at": "2026-07-28 10:22:19.602461",
          },
        },
      };
    }

    if (endpoint.contains(ApiConstants.logNoteMessages)) {
      return {
        "success": true,
        "message": "Messages fetched successfully",
        "data": {
          "items": [
            {
              "id": 1,
              "expense_id": 123,
              "sender_name": "System",
              "is_user": false,
              "message": "Expense created successfully.",
              "timestamp": "2026-07-28T09:00:00",
              "attachments": [],
              "mention_names": [],
            },
            {
              "id": 2,
              "expense_id": 123,
              "sender_name": "You",
              "is_user": true,
              "message": "Please review this expense.",
              "timestamp": "2026-07-29T10:30:00",
              "attachments": [],
              "mention_names": [],
            },
          ],
          "pagination": {
            "page": 1,
            "limit": 30,
            "total": 2,
            "has_next": false,
            "has_previous": false,
          },
        },
      };
    }

    if (endpoint.contains(ApiConstants.termsConditions)) {
      return {
        "success": true,
        "message": "Terms & conditions fetched successfully",
        "data": {
          "terms_conditions": {
            "id": 1,
            "title": "Terms & Conditions",
            "body":
                "<p data-oe-version=\"2.0\">Terms &amp; Conditions content has not been set yet.<br><font style=\"color: rgb(255, 0, 0);\">Test</font></p>",
            "is_published": true,
            "updated_at": "2026-07-28 10:23:33.832133",
          },
        },
      };
    }

    if (endpoint.contains(ApiConstants.profile)) {
      return {
        "success": true,
        "message": "Profile fetched successfully",
        "data": {
          "id": 1,
          "name": "Administrator",
          "job_title": null,
          "email": null,
          "phone": null,
          "mobile": null,
          "department": "Administration",
          "company": "My Company",
          "work_location": null,
          "avatar_url":
              "https://example.com/api/mobile/v1/employees/1/avatar",
          "initials": "A",
          "header": {
            "name": "Administrator",
            "job_title": null,
            "avatar_url":
                "https://example.com/api/mobile/v1/employees/1/avatar",
            "initials": "A",
          },
          "work": {
            "email": "admin@company.com",
            "phone": "+1 234 567 8900",
            "job_title": "System Administrator",
            "job_position": "Administration",
            "manager": "Executive Office",
            "contract_start_date": "2024-01-01",
            "contract_start_date_display": "Jan 1, 2024",
            "bank": {
              "bank_name": "Silicon Valley Bank",
              "account_number": "123456789012",
              "ifsc_code": "SVB0001234",
            },
          },
          "personal": {
            "personal_email": "jane.doe@example.com",
            "phone": "+1 234 567 8900",
            "blood_group": "A+",
            "gender": "Male",
            "date_of_birth": "1990-05-15",
            "date_of_birth_display": "May 15, 1990",
            "marital_status": null,
            "nationality": null,
            "birth_place": null,
            "residential_address": null,
            "permanent_address": null,
            "education_level": null,
            "field_of_study": null,
          },
          "docs": {
            "company_id": {
              "available": false,
              "name": "Company ID",
              "download": null,
            },
            "certificates": [
              {
                "id": 5860,
                "name": "apis.json",
                "filename": "apis.json",
                "mimetype": "application/json",
                "file_size": 7374,
                "download": {
                  "endpoint": "/api/mobile/v1/profile/documents/5860/download",
                  "method": "GET",
                  "requires_auth": true,
                  "response": "base64",
                },
              },
            ],
          },
          "report_to": null,
          "team": [],
        },
      };
    }

    if (endpoint.contains('/profile/documents/') &&
        endpoint.contains('/download')) {
      return {
        "success": true,
        "message": "Document downloaded successfully",
        "data": {
          "filename": "apis.json",
          "content_type": "application/json",
          "base64":
              "QXBpIERldGFpbHMNCg0KDQpOb3RpZmljYXRpb24gQXBpDQoNClJlc3BvbnNlOiB7DQogICAgInN1Y2Nlc3MiOiB0cnVlLA0KICAgICJtZXNzYWdlIjogIk5vdGlmaWNhdGlvbnMgZmV0Y2hlZCBzdWNjZXNzZnVsbHkiLA0KICAgICJkYXRhIjogew0KICAgICAgICAidW5yZWFkX2NvdW50IjogNSwNCiAgICAgICAgInRvdGFsX2NvdW50IjogMjQNCiAgICB9DQp9",
        },
      };
    }

    if (endpoint.contains(ApiConstants.timeOff) &&
        !endpoint.contains(ApiConstants.timeOffHistory) &&
        !endpoint.contains(ApiConstants.timeOffUpcoming) &&
        !endpoint.contains(ApiConstants.timeOffTypes) &&
        !endpoint.contains(ApiConstants.timeOffDuration)) {
      return {
        "success": true,
        "message": "Time off fetched successfully",
        "data": {
          "balances": [
            {
              "id": 1,
              "name": "Annual Paid Time Off / Vacation Leave",
              "remaining": 14.5,
              "total_allocated": 20,
              "taken": 5.5,
              "pending": 0,
              "unit": "day",
            },
            {
              "id": 2,
              "name": "Sick and Medical Contingency Emergency Leave",
              "remaining": 10.0,
              "total_allocated": 12,
              "taken": 2.0,
              "pending": 0,
              "unit": "day",
            },
            {
              "id": 3,
              "name": "Compensatory Off-Time Earned Rest Day Balance",
              "remaining": 12.0,
              "total_allocated": 12,
              "taken": 0,
              "pending": 0,
              "unit": "day",
            },
          ],
          "total_remaining_leave": 14.5,
          "upcoming": [
            {
              "id": 4,
              "name": "Summer Vacation in Europe",
              "leave_type": {
                "id": 1,
                "name": "Annual Paid Time Off / Vacation Leave",
              },
              "date_from": "2026-08-15",
              "date_to": "2026-08-20",
              "days": 5,
              "stage": "approved",
            },
          ],
          "history": [
            {
              "id": 6,
              "name": "Q2 Launch Rest Day",
              "leave_type": {
                "id": 3,
                "name": "Compensatory Off-Time Earned Rest Day Balance",
              },
              "date_from": "2026-06-20",
              "date_to": "2026-06-21",
              "days": 2,
              "stage": "approved",
            },
          ],
        },
      };
    }

    if (endpoint.contains(ApiConstants.timeOffHistory)) {
      return {
        "success": true,
        "message": "Time off history fetched successfully",
        "data": {
          "leaves": [
            {
              "timeline": "June 2026",
              "leaves": [
                {
                  "id": 6,
                  "name": "Q2 Launch Rest Day",
                  "leave_type": {
                    "id": 3,
                    "name": "Compensatory Off-Time Earned Rest Day Balance",
                  },
                  "date_from": "2026-06-20",
                  "date_to": "2026-06-21",
                  "days": 2,
                  "stage": "approved",
                },
              ],
            },
          ],
          "pagination": {
            "page": 1,
            "page_size": 10,
            "total": 1,
            "total_pages": 1,
          },
        },
      };
    }

    if (endpoint.contains(ApiConstants.timeOffUpcoming)) {
      return {
        "success": true,
        "message": "Upcoming leaves fetched successfully",
        "data": {
          "leaves": [
            {
              "timeline": "August 2026",
              "leaves": [
                {
                  "id": 4,
                  "name": "Summer Vacation in Europe",
                  "leave_type": {
                    "id": 1,
                    "name": "Annual Paid Time Off / Vacation Leave",
                  },
                  "date_from": "2026-08-15",
                  "date_to": "2026-08-20",
                  "days": 5,
                  "stage": "approved",
                },
              ],
            },
          ],
          "pagination": {
            "page": 1,
            "page_size": 10,
            "total": 1,
            "total_pages": 1,
          },
        },
      };
    }

    if (endpoint.contains(ApiConstants.timeOffTypes)) {
      return {
        "success": true,
        "message": "Time off types fetched successfully",
        "data": [
          {
            "id": 1,
            "name": "Annual Paid Time Off",
            "code": "paid_time_off",
            "remaining": 14.5,
            "remaining_display": "14.5 Days",
            "unit": "day",
            "is_unlimited": false,
            "can_apply": true,
            "requires_allocation": true,
            "supports_negative": false,
            "color": "#FF5722",
          },
          {
            "id": 2,
            "name": "Sick Leave",
            "code": "sick_leave",
            "remaining": 10.0,
            "remaining_display": "10.0 Days",
            "unit": "day",
            "is_unlimited": false,
            "can_apply": true,
            "requires_allocation": true,
            "supports_negative": false,
            "color": "#34C759",
          },
        ],
      };
    }

    if (endpoint.contains(ApiConstants.timeOffDuration)) {
      return {
        "success": true,
        "message": "Duration calculated successfully",
        "data": {
          "duration": 5,
          "unit": "days",
          "display": "5 Days",
          "start_date": "2026-08-15",
          "end_date": "2026-08-20",
          "can_apply": true,
          "warning": null,
        },
      };
    }

    if ((endpoint == ApiConstants.expensesList ||
            endpoint.startsWith('${ApiConstants.expensesList}?')) &&
        method == 'GET') {
      return {
        "success": true,
        "message": "Expenses fetched successfully",
        "data": {
          "groups": [
            {
              "timeline": "Jul 03 - Jul 06, 2026",
              "total_amount": 1735.49,
              "total_amount_display": "(\$1,735.49)",
              "currency": "USD",
              "expenses": [
                {
                  "id": 10,
                  "title": "Business travel to Singapore - flights & hotel",
                  "category": "Travel & Accommodation",
                  "date": "2026-07-06",
                  "amount": 1450.00,
                  "amount_display": "(\$1,450.00)",
                  "currency": "USD",
                  "status": "pending",
                  "status_display": "Pending Approval",
                  "icon": "receipt",
                  "has_receipt": true,
                },
                {
                  "id": 11,
                  "title": "Monthly internet subscription",
                  "category": "Communication",
                  "date": "2026-07-05",
                  "amount": 89.99,
                  "amount_display": "(\$89.99)",
                  "currency": "USD",
                  "status": "approved",
                  "status_display": "Approved",
                  "icon": "receipt",
                  "has_receipt": true,
                },
                {
                  "id": 12,
                  "title": "Team lunch - project kickoff",
                  "category": "Meals",
                  "date": "2026-07-04",
                  "amount": 120.50,
                  "amount_display": "(\$120.50)",
                  "currency": "USD",
                  "status": "approved",
                  "status_display": "Approved",
                  "icon": "receipt",
                  "has_receipt": true,
                },
                {
                  "id": 13,
                  "title": "Client appreciation gift basket",
                  "category": "Gifts",
                  "date": "2026-07-03",
                  "amount": 75.00,
                  "amount_display": "(\$75.00)",
                  "currency": "USD",
                  "status": "pending",
                  "status_display": "Pending Approval",
                  "icon": "receipt",
                  "has_receipt": true,
                },
              ],
            },
          ],
          "pagination": {
            "page": 1,
            "limit": 20,
            "total": 4,
            "has_next": false,
            "has_previous": false,
          },
        },
      };
    }

    if (endpoint.contains(ApiConstants.expenseSummary)) {
      return {
        "success": true,
        "message": "Expense summary fetched successfully",
        "data": {
          "pending_reimbursement_amount": 1525.00,
          "pending_reimbursement_display": "\$1,525.00",
          "pending_count": 2,
          "average_approval_time": {
            "value": 3,
            "unit": "business_days",
            "display": "3 business days",
            "source": "default",
          },
          "recent_expenses": [
            {
              "id": 10,
              "title": "Business travel to Singapore - flights & hotel",
              "category": "Travel & Accommodation",
              "date": "2026-07-06",
              "amount": 1450.00,
              "amount_display": "(\$1,450.00)",
              "currency": "USD",
              "status": "pending",
              "status_display": "Pending Approval",
              "icon": "receipt",
              "has_receipt": true,
            },
            {
              "id": 13,
              "title": "Client appreciation gift basket",
              "category": "Gifts",
              "date": "2026-07-03",
              "amount": 75.00,
              "amount_display": "(\$75.00)",
              "currency": "USD",
              "status": "pending",
              "status_display": "Pending Approval",
              "icon": "receipt",
              "has_receipt": true,
            },
          ],
        },
      };
    }

    if (endpoint.contains(ApiConstants.timeOffCalendarMonth)) {
      return {
        "success": true,
        "message": "Time off calendar month fetched successfully",
        "data": {
          "year": 2026,
          "month": 6,
          "month_label": "June 2026",
          "days": List.generate(30, (index) {
            final day = index + 1;
            final dayStr = day.toString().padLeft(2, '0');
            final types = <String>[];
            if (day == 5) {
              types.add('paid_time_off');
            } else if (day == 12) {
              types.add('sick_leave');
            } else if (day == 25) {
              types.add('paid_time_off');
              types.add('sick_leave');
            }
            return {
              "date": "2026-06-$dayStr",
              "day": day,
              "item_count": types.length,
              "types": types,
            };
          }),
        },
      };
    }

    if (endpoint.contains(ApiConstants.calendarMonth)) {
      return {
        "success": true,
        "message": "Calendar month fetched successfully",
        "data": {
          "year": 2026,
          "month": 6,
          "month_label": "June 2026",
          "days": List.generate(30, (index) {
            final day = index + 1;
            final dayStr = day.toString().padLeft(2, '0');
            final types = <String>[];
            if (day == 3) {
              types.add('meeting');
            } else if (day == 5 || day == 25) {
              types.add('meeting');
              types.add('leave');
            }
            return {
              "date": "2026-06-$dayStr",
              "day": day,
              "item_count": types.length,
              "types": types,
            };
          }),
        },
      };
    }

    if (endpoint.contains(ApiConstants.timeOffCalendarDay)) {
      return {
        "success": true,
        "message": "Time off calendar day fetched successfully",
        "data": {
          "date": "2026-07-11",
          "date_label": "Saturday, July 11",
          "items": [
            {
              "id": 195,
              "title": "Test",
              "reason": "Test",
              "leave_type": "Sick Time Off",
              "leave_type_code": "sick_time_off",
              "start_date": "2026-07-10",
              "end_date": "2026-07-23",
              "duration": 10,
              "duration_display": "10 Days",
              "summary_display": "10 Days · Sick Time Off",
              "status": "pending",
              "status_display": "Pending",
              "color": "#F7CD1F",
            },
          ],
        },
      };
    }

    if (endpoint.contains(ApiConstants.calendarDay)) {
      return {
        "success": true,
        "message": "Calendar day schedule fetched successfully",
        "data": {
          "date": "2026-06-09",
          "items": [
            {
              "id": 1,
              "title": "Daily Stand-up Meeting",
              "subtitle": "08:00 - 08:30 am",
              "type": "meeting",
              "accent_color": "#FF5722",
            },
            {
              "id": 2,
              "title": "Sprint Planning & Backlog Refinement",
              "subtitle": "10:00 - 11:30 am",
              "type": "meeting",
              "accent_color": "#FF5722",
            },
            {
              "id": 3,
              "title": "Casual Leave - Family Function",
              "subtitle": "Full Day",
              "type": "leave",
              "accent_color": "#076330",
            },
            {
              "id": 4,
              "title": "Client Technical Sync",
              "subtitle": "02:00 - 03:00 pm",
              "type": "meeting",
              "accent_color": "#FF5722",
            },
            {
              "id": 5,
              "title": "Architecture & Design Review",
              "subtitle": "04:30 - 05:30 pm",
              "type": "meeting",
              "accent_color": "#FF5722",
            },
          ],
        },
      };
    }

    // 1. Home
    if (endpoint.contains(ApiConstants.home)) {
      return {
        "success": true,
        "message": "Home data fetched successfully",
        "data": {
          "home": {
            "attendance": {
              "enabled": true,
              "status": "not_checked_in",
              "check_in": "2026-08-02T09:00:00.000Z",
              "check_out": "2026-08-02T17:30:00.000Z",
              "display_time": "09:00 AM",
            },
            "total_remaining_leave": 14.5,
            "payslip": {
              "enabled": true,
              "month": "August 2026",
              "final_amount": 4500.0,
              "currency": {"id": 1, "name": "USD", "symbol": "\$"},
            },
            "expense": {
              "enabled": true,
              "month": "August 2026",
              "total_amount": 1525.0,
              "currency": {"id": 1, "name": "USD", "symbol": "\$"},
            },
            "calendar": {
              "enabled": true,
              "date": "2026-08-02",
              "items": [
                {
                  "id": 1,
                  "title": "Daily Stand-up Meeting",
                  "subtitle": "09:00 AM",
                  "type": "meeting",
                  "accent_color": "#FF5722",
                },
                {
                  "id": 2,
                  "title": "Meeting with Sam and co..",
                  "subtitle": "05:30 PM",
                  "type": "meeting",
                  "accent_color": "#FF5722",
                },
                {
                  "id": 3,
                  "title": "Design Review & Sync",
                  "subtitle": "02:00 PM",
                  "type": "meeting",
                  "accent_color": "#FF5722",
                },
                {
                  "id": 4,
                  "title": "Client Status Update",
                  "subtitle": "04:15 PM",
                  "type": "meeting",
                  "accent_color": "#FF5722",
                },
              ],
            },
            "has_unread_notifications": true,
          },
        },
      };
    }

    if (endpoint.contains(ApiConstants.attendanceAction)) {
      return {
        "success": true,
        "message": "Attendance recorded successfully",
        "data": {
          "enabled": true,
          "status": "checked_in",
          "check_in": "2026-08-02T09:00:00.000Z",
          "check_out": null,
          "display_time": "09:00 AM",
        },
      };
    }

    if (endpoint.contains(ApiConstants.attendanceLogs)) {
      return {
        "success": true,
        "message": "Attendance logs fetched successfully",
        "data": {
          "items": [
            {
              "id": 1,
              "date": "2026-08-02",
              "check_in": "2026-08-02T09:00:00.000Z",
              "check_out": "2026-08-02T17:30:00.000Z",
              "worked_hours": 8.5,
              "status": "present",
              "status_display": "Present",
            },
            {
              "id": 2,
              "date": "2026-08-01",
              "check_in": "2026-08-01T08:55:00.000Z",
              "check_out": "2026-08-01T17:15:00.000Z",
              "worked_hours": 8.3,
              "status": "present",
              "status_display": "Present",
            },
          ],
          "pagination": {
            "page": 1,
            "limit": 10,
            "total": 2,
            "has_next": false,
            "has_previous": false,
          },
        },
      };
    }

    // 2. Access Details
    if (endpoint.contains(ApiConstants.accessDetails)) {
      return {
        "success": true,
        "message": "User access details",
        "data": {
          "user": {
            "id": 1,
            "name": "Design User",
            "login": "design_user",
            "active": true,
            "mobile_user": true,
          },
          "company": {
            "default_company_id": 1,
            "default_company_currency": {
              "id": 1,
              "name": "USD",
              "symbol": "\$",
            },
          },
          "config": {
            "login_enabled": true,
            "maintenance_mode": false,
            "max_devices": 0,
            "push_notifications_enabled": true,
          },
          "features": [
            {
              "code": "attendance",
              "name": "Attendance",
              "active": true,
              "gps": {
                "enabled": false,
                "checkin_required": false,
                "checkout_required": false,
                "company_latitude": 0.0,
                "company_longitude": 0.0,
                "boundary_meters": 100,
              },
            },
            {"code": "payslip", "name": "Payslip", "active": true, "gps": null},
            {
              "code": "expense",
              "name": "Expense",
              "active": false,
              "can_read": false,
              "can_write": false,
              "gps": null,
            },
            {
              "code": "time_off",
              "name": "Time Off",
              "active": true,
              "gps": null,
            },
            {
              "code": "calendar",
              "name": "Calendar",
              "active": true,
              "gps": null,
            },
          ],
        },
      };
    }

    // 3. Payslip History List
    if (endpoint.contains(ApiConstants.payslipList)) {
      return {
        "success": true,
        "message": "Payslips fetched successfully",
        "data": {
          "payslips": [
            {
              "id": 998,
              "period": "June 2026",
              "date_from": "2026-06-01",
              "date_to": "2026-06-30",
              "net_pay": 4200.0,
              "state": "paid",
              "distributed_date": "2026-06-30",
            },
            {
              "id": 997,
              "period": "May 2026",
              "date_from": "2026-05-01",
              "date_to": "2026-05-31",
              "net_pay": 4200.0,
              "state": "paid",
              "distributed_date": "2026-05-31",
            },
            {
              "id": 996,
              "period": "December 2025",
              "date_from": "2025-12-01",
              "date_to": "2025-12-31",
              "net_pay": 4350.0,
              "state": "paid",
              "distributed_date": "2025-12-31",
            },
            {
              "id": 995,
              "period": "November 2025",
              "date_from": "2025-11-01",
              "date_to": "2025-11-30",
              "net_pay": 4100.0,
              "state": "paid",
              "distributed_date": "2025-11-30",
            },
          ],
          "pagination": {
            "page": 1,
            "page_size": 10,
            "total": 4,
            "total_pages": 1,
          },
        },
      };
    }

    // 4. Payslip Overview & History
    if (endpoint.contains(ApiConstants.payslip) &&
        !endpoint.contains('download')) {
      return {
        "success": true,
        "message": "Payslip fetched successfully",
        "data": {
          "id": 999,
          "period": "July 2026",
          "date_from": "2026-07-01",
          "date_to": "2026-07-31",
          "net_pay": 4500.0,
          "state": "paid",
          "distributed_date": "2026-07-31",
          "earnings": [
            {"code": "BASIC", "name": "Basic Pay", "amount": 4000.0},
            {"code": "BONUS", "name": "Performance Bonus", "amount": 600.0},
          ],
          "deductions": [
            {"code": "TAX", "name": "Tax & Deductions", "amount": -100.0},
          ],
          "history": [
            {
              "id": 998,
              "period": "June 2026",
              "date_from": "2026-06-01",
              "date_to": "2026-06-30",
              "net_pay": 4200.0,
              "state": "paid",
              "distributed_date": "2026-06-30",
              "earnings": [],
              "deductions": [],
            },
            {
              "id": 997,
              "period": "May 2026",
              "date_from": "2026-05-01",
              "date_to": "2026-05-31",
              "net_pay": 4200.0,
              "state": "paid",
              "distributed_date": "2026-05-31",
              "earnings": [],
              "deductions": [],
            },
          ],
        },
      };
    }

    // 4. Payslip Download
    if (endpoint.contains('download')) {
      return {
        "success": true,
        "message": "Payslip PDF generated successfully",
        "data": {
          "filename": "Design_Payslip.pdf",
          "content_type": "application/pdf",
          "base64":
              "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ZXNvdXJjZSBiZWdpbgoxMiBkaWN0IGJlZ2luCmJlZ2luY21hcAovQ0lEU3lzdGVtSW5mbyA8PCAvUmVnaXN0cnkgKEFkb2JlKSAvT3JkZXJpbmcgKFVDUykgL1N1cHBsZW1lbnQgMCA+PiBkZWYKL0NNYXBOYW1lIC9BZG9iZS1JZGVudGl0eS1VQ1MgZGVmCi9DTWFwVHlwZSAyIGRlZgoxIGJlZ2luY29kZXNwYWNlcmFuZ2UKPDAwMDA+IDxGRkZGPgplbmRjb2Rlc3BhY2VyYW5nZQoyIGJlZ2luYmZyYW5nZQo8MDAwMD4gPDAwMDA+IDwwMDAwPgo8MDAwMT4gPDAwM0E+IFs8MDA0QT4gPDAwNzU+IDwwMDZFPiA8MDA2NT4gPDAwMDk+IDwwMDMyPiA8MDAzMD4gPDAwMzY+IDwwMDUwPiA8MDA2MT4gPDAwNzk+IDwwMDczPiA8MDA2Qz4gPDAwNjk+IDwwMDcwPiA8MDA0NT4gPDAwNkQ+IDwwMDZGPiA8MDA0OT4gPDAwNjY+IDwwMDcyPiA8MDA3ND4gPDAwNEY+IDwwMDY4PiA8MDA0RT4gPDAwM0E+IDwwMDU0PiA8MDAzMT4gPDAwNDQ+IDwwMDYyPiA8MDA0RD4gPDAwNTM+IDwwMDY3PiA8MDA0Mz4gPDAwNjM+IDwwMDU3PiA8MDAyOD4gPDAwMjk+IDwwMDI0PiA8MDAyRT4gPDAwNjQ+IDwwMDJGPiA8MDAyRD4gPDAwMzM+IDwwMDZCPiA8MDAzND4gPDAwNDg+IDwwMDQxPiA8MDA1MT4gPDAwNTI+IDwwMDQyPiA8MDAyQz4gPDAwMzU+IDwwMDc4PiA8MDAyNj4gPDIwMEI+IDwwMDM4PiA8MDA1NT4gXQplbmRiZnJhbmdlCmVuZGNtYXAKQ01hcE5hbWUgY3VycmVudGRpY3QgL0NNYXAgZGVmaW5lcmVzb3VyY2UgcG9wCmVuZAplbmQKCmVuZHN0cmVhbQplbmRvYmoKNiAwIG9iago8PCAvVHlwZSAvRm9udAovU3VidHlwZSAvVHlwZTAKL0Jhc2VGb250IC9Sb2JvdG8tUmVndWxhcgovRW5jb2RpbmcgL0lkZW50aXR5LUgKL0Rlc2NlbmRhbnRGb250cyBbMjIgMCBSXQovVG9Vbmljb2RlIDIzIDAgUj4+CmVuZG9iagoyIDAgb2JqCjw8Ci9UeXBlIC9QYWdlcwovS2lkcyAKWwo1IDAgUgpdCi9Db3VudCAxCi9Qcm9jU2V0IFsvUERGIC9UZXh0IC9JbWFnZUIgL0ltYWdlQ10KPj4KZW5kb2JqCnhyZWYKMCAyNQowMDAwMDAwMDAwIDY1NTM1IGYgCjAwMDAwMDAwMDkgMDAwMDAgbiAKMDAwMDAxODAwNSAwMDAwMCBuIAowMDAwMDAwMTU3IDAwMDAwIG4gCjAwMDAwMDAyNTIgMDAwMDAgbiAKMDAwMDAwOTAyNCAwMDAwMCBuIAowMDAwMDE3ODY1IDAwMDAwIG4gCjAwMDAwMDAyODkgMDAwMDAgbiAKMDAwMDAwMDM0MCAwMDAwMCBuIAowMDAwMDA0NjQzIDAwMDAwIG4gCjAwMDAwMDQ2NjMgMDAwMDAgbiAKMDAwMDAwODY3NyAwMDAwMCBuIAowMDAwMDA4Njk4IDAwMDAwIG4gCjAwMDAwMDg4NTcgMDAwMDAgbiAKMDAwMDAwODc0MCAwMDAwMCBuIAowMDAwMDA4OTIwIDAwMDAwIG4gCjAwMDAwMDkzNDQgMDAwMDAgbiAKMDAwMDAxMTI5NSAwMDAwMCBuIAowMDAwMDA5MTQ1IDAwMDAwIG4gCjAwMDAwMDkzMjQgMDAwMDAgbiAKMDAwMDAxMTMxNiAwMDAwMCBuIAowMDAwMDExNTgwIDAwMDAwIG4gCjAwMDAwMTY1OTUgMDAwMDAgbiAKMDAwMDAxNzA0MyAwMDAwMCBuIAowMDAwMDE2NTc0IDAwMDAwIG4gCnRyYWlsZXIKPDwKL1NpemUgMjUKL0luZm8gMSAwIFIKL1Jvb3QgMTUgMCBSCj4+CnN0YXJ0eHJlZgoxODEwMwolJUVPRgo=",
        },
      };
    }

    // 5. Login / Refresh
    if (endpoint.contains(ApiConstants.login) ||
        endpoint.contains(ApiConstants.refresh)) {
      return {
        "success": true,
        "message": "Login successful",
        "data": {
          "token": "dummy_design_mode_token_123456789",
          "refresh_token": "dummy_design_mode_refresh_token_987654321",
          "user_id": 1,
          "name": "Design User",
          "company_id": 1,
        },
      };
    }

    // 7. Time Off
    if (endpoint == ApiConstants.timeOff ||
        endpoint.startsWith('${ApiConstants.timeOff}?')) {
      return {
        "success": true,
        "message": "Time off fetched successfully",
        "data": {
          "balances": [
            {
              "id": 1,
              "name": "Paid Time Off",
              "remaining": 5,
              "total_allocated": 12,
              "taken": 3,
              "pending": 4,
              "unit": "day",
            },
            {
              "id": 2,
              "name": "Sick Time Off",
              "remaining": 15,
              "total_allocated": 15,
              "taken": 0,
              "pending": 0,
              "unit": "day",
            },
            {
              "id": 3,
              "name": "Compensatory Off",
              "remaining": 2,
              "total_allocated": 2,
              "taken": 0,
              "pending": 0,
              "unit": "day",
            },
            {
              "id": 4,
              "name": "Unpaid",
              "remaining": 0,
              "total_allocated": 0,
              "taken": 5,
              "pending": 0,
              "unit": "hour",
            },
            {
              "id": 5,
              "name": "Casual Leave",
              "remaining": 3,
              "total_allocated": 6,
              "taken": 3,
              "pending": 0,
              "unit": "day",
            },
            {
              "id": 6,
              "name": "Extra Hours",
              "remaining": 40,
              "total_allocated": 40,
              "taken": 0,
              "pending": 0,
              "unit": "hour",
            },
            {
              "id": 7,
              "name": "Maternity Leave",
              "remaining": 90,
              "total_allocated": 90,
              "taken": 0,
              "pending": 0,
              "unit": "day",
            },
            {
              "id": 8,
              "name": "Paternity Leave",
              "remaining": 10,
              "total_allocated": 10,
              "taken": 0,
              "pending": 0,
              "unit": "day",
            },
          ],
          "total_remaining_leave": 5,
          "upcoming": [
            {
              "id": 4,
              "name": "Fever",
              "leave_type": {"id": 1, "name": "Paid Time Off"},
              "date_from": "2026-07-14",
              "date_to": "2026-07-14",
              "days": 1,
              "stage": "approved",
            },
            {
              "id": 5,
              "name": "Vacation trip",
              "leave_type": {"id": 1, "name": "Paid Time Off"},
              "date_from": "2026-08-02",
              "date_to": "2026-08-06",
              "days": 4,
              "stage": "pending",
            },
          ],
          "history": [
            {
              "id": 6,
              "name": "Wedding Ceremony",
              "leave_type": {"id": 1, "name": "Paid Time Off"},
              "date_from": "2026-06-20",
              "date_to": "2026-06-23",
              "days": 2,
              "stage": "approved",
            },
            {
              "id": 7,
              "name": "Sick Leave",
              "leave_type": {"id": 1, "name": "Paid Time Off"},
              "date_from": "2026-05-12",
              "date_to": "2026-05-12",
              "days": 1,
              "stage": "rejected",
            },
          ],
        },
      };
    }

    if (method == 'GET' && endpoint == '/api/mobile/v1/expense/categories') {
      return {
        "success": true,
        "message": "Expense categories fetched successfully",
        "data": [
          {
            "id": 6,
            "name": "Communication",
            "icon": "receipt",
            "sequence": 10,
            "requires_receipt": false,
          },
          {
            "id": 7,
            "name": "Expenses",
            "icon": "receipt",
            "sequence": 20,
            "requires_receipt": false,
          },
          {
            "id": 5,
            "name": "Gifts",
            "icon": "receipt",
            "sequence": 30,
            "requires_receipt": false,
          },
          {
            "id": 2,
            "name": "Meals",
            "icon": "utensils",
            "sequence": 40,
            "requires_receipt": false,
          },
          {
            "id": 4,
            "name": "Mileage",
            "icon": "plane",
            "sequence": 50,
            "requires_receipt": false,
          },
          {
            "id": 3,
            "name": "Travel & Accommodation",
            "icon": "plane",
            "sequence": 60,
            "requires_receipt": false,
          },
          {
            "id": 8,
            "name": "Training",
            "icon": "receipt",
            "sequence": 70,
            "requires_receipt": false,
          },
          {
            "id": 9,
            "name": "Office Supplies",
            "icon": "receipt",
            "sequence": 80,
            "requires_receipt": false,
          },
        ],
      };
    }

    if (method == 'POST' && endpoint == '/api/mobile/v1/expense') {
      return {
        "success": true,
        "message": "Expense created successfully",
        "data": {
          "id": 999,
          "title": "New Expense",
          "category": "Expenses",
          "date": "2026-07-06",
          "amount": 32.10,
          "amount_display": "(\$32.10)",
          "currency": "USD",
          "status": "draft",
          "status_display": "Draft",
          "icon": "receipt",
          "has_receipt": true,
        },
      };
    }

    if (method == 'GET' &&
        endpoint.contains('/api/mobile/v1/timeoff/history')) {
      return {
        "success": true,
        "message": "Leave history fetched successfully",
        "data": {
          "leaves": [
            {
              "id": 6,
              "name": "Wedding Ceremony",
              "leave_type": {"id": 1, "name": "Paid Time Off"},
              "date_from": "2026-06-20",
              "date_to": "2026-06-23",
              "days": 2,
              "stage": "approved",
            },
            {
              "id": 7,
              "name": "Sick Leave",
              "leave_type": {"id": 1, "name": "Paid Time Off"},
              "date_from": "2026-05-12",
              "date_to": "2026-05-12",
              "days": 1,
              "stage": "rejected",
            },
          ],
          "pagination": {
            "page": 1,
            "page_size": 10,
            "total": 2,
            "total_pages": 1,
          },
        },
      };
    }

    if (method == 'GET' && endpoint == '/api/mobile/v1/timeoff/types') {
      return {
        "success": true,
        "message": "Time off types fetched successfully",
        "data": [
          {
            "id": 1,
            "name": "Paid Time Off",
            "code": "paid_time_off",
            "remaining": 5,
            "remaining_display": "5",
            "unit": "days",
            "is_unlimited": false,
            "can_apply": true,
            "requires_allocation": true,
            "supports_negative": false,
            "color": "#F4A460",
          },
          {
            "id": 2,
            "name": "Sick Time Off",
            "code": "sick_time_off",
            "remaining": null,
            "remaining_display": "Unlimited",
            "unit": "days",
            "is_unlimited": true,
            "can_apply": true,
            "requires_allocation": false,
            "supports_negative": false,
            "color": "#F7CD1F",
          },
          {
            "id": 3,
            "name": "Compensatory Off",
            "code": "compensatory_off",
            "remaining": 2,
            "remaining_display": "2",
            "unit": "days",
            "is_unlimited": false,
            "can_apply": true,
            "requires_allocation": true,
            "supports_negative": false,
            "color": "#4CAF50",
          },
          {
            "id": 4,
            "name": "Unpaid",
            "code": "unpaid",
            "remaining": null,
            "remaining_display": "Unlimited",
            "unit": "hours",
            "is_unlimited": true,
            "can_apply": true,
            "requires_allocation": false,
            "supports_negative": false,
            "color": "#814968",
          },
          {
            "id": 5,
            "name": "Casual Leave",
            "code": "casual_leave",
            "remaining": 3,
            "remaining_display": "3",
            "unit": "days",
            "is_unlimited": false,
            "can_apply": true,
            "requires_allocation": true,
            "supports_negative": false,
            "color": "#2196F3",
          },
          {
            "id": 6,
            "name": "Extra Hours",
            "code": "extra_hours",
            "remaining": null,
            "remaining_display": "Unlimited",
            "unit": "hours",
            "is_unlimited": true,
            "can_apply": true,
            "requires_allocation": false,
            "supports_negative": false,
            "color": "#E47E65",
          },
          {
            "id": 7,
            "name": "Maternity Leave",
            "code": "maternity_leave",
            "remaining": 90,
            "remaining_display": "90",
            "unit": "days",
            "is_unlimited": false,
            "can_apply": true,
            "requires_allocation": true,
            "supports_negative": false,
            "color": "#E91E63",
          },
          {
            "id": 8,
            "name": "Paternity Leave",
            "code": "paternity_leave",
            "remaining": 10,
            "remaining_display": "10",
            "unit": "days",
            "is_unlimited": false,
            "can_apply": true,
            "requires_allocation": true,
            "supports_negative": false,
            "color": "#9C27B0",
          },
        ],
      };
    }

    if (endpoint.contains('/api/mobile/v1/timeoff/duration')) {
      return {
        "success": true,
        "message": "Duration calculated successfully",
        "data": {
          "duration": 2,
          "unit": "days",
          "display": "2 Days",
          "start_date": "2026-06-28",
          "end_date": "2026-06-30",
          "can_apply": true,
          "warning": null,
        },
      };
    }

    if (endpoint.contains('/api/mobile/v1/timeoff/request')) {
      return {
        "success": true,
        "message": "Leave request submitted successfully",
        "data": null,
      };
    }

    if (endpoint.contains('/api/mobile/v1/log-note/mention-suggestions')) {
      return {
        "success": true,
        "message": "Mention suggestions loaded successfully.",
        "data": {
          "search": "",
          "limit": 20,
          "total": 6,
          "has_more": false,
          "suggestions": [
            {
              "id": 3,
              "name": "Administrator",
              "email": "admin@company.com",
              "image_url": "https://i.pravatar.cc/150?img=11",
              "is_internal_user": true,
              "user_id": 2,
            },
            {
              "id": 616,
              "name": "Test Grade Level Employee",
              "email": null,
              "image_url": "https://i.pravatar.cc/150?img=12",
              "is_internal_user": false,
              "user_id": null,
            },
            {
              "id": 395,
              "name":
                  "Nevada Department of Employment, Training and Rehabilitation",
              "email": null,
              "image_url": "https://i.pravatar.cc/150?img=5",
              "is_internal_user": false,
              "user_id": null,
            },
            {
              "id": 398,
              "name": "Colorado Department of Revenue",
              "email": null,
              "image_url": "https://i.pravatar.cc/150?img=13",
              "is_internal_user": false,
              "user_id": null,
            },
            {
              "id": 633,
              "name": "Ishel thomas",
              "email": null,
              "image_url": "https://i.pravatar.cc/150?img=9",
              "is_internal_user": false,
              "user_id": null,
            },
            {
              "id": 405,
              "name": "Colorado Department of Labor and Employment",
              "email": null,
              "image_url": "https://i.pravatar.cc/150?img=8",
              "is_internal_user": false,
              "user_id": null,
            },
          ],
        },
      };
    }

    // Default fallback
    return {
      "success": true,
      "message": "Mock response for $endpoint",
      "data": {},
    };
  }
}
