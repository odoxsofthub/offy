# Odoo 18 port of odx_mobile_connector / odx_mobile_api

## Expenses
- Odoo 18 groups expenses in `hr.expense.sheet`; the API creates one sheet per app claim.
- Odoo 18 has no auto-approve: a submitted sheet waits for a manager.
- App status mapping (sheet `state` -> app):

| Odoo 18 state        | App status |
|----------------------|------------|
| `done`               | `paid`     |
| `approved`           | `approved` |
| `submitted`          | `pending`  |
| `draft`, `reported`  | `draft`    |

