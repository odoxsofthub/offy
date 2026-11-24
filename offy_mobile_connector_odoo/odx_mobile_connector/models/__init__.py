from . import mobile_feature
from . import mobile_user_feature
from . import mobile_config
from . import mobile_user_session
from . import mobile_device_token
from . import mobile_notification_log
from . import mobile_push_service
from . import mobile_realtime_ticket
from . import mobile_sync_service
from . import ir_websocket
from . import mobile_privacy_policy
from . import mobile_terms_condition
from . import mobile_faq
from . import res_users
# Order matters: hr_work_location imports the GPS_BOUNDARY_* bounds from mobile_config.
from . import hr_work_location
from . import hr_employee
from . import hr_attendance
