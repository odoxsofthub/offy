/** @odoo-module **/

import { registry } from "@web/core/registry";
import { Component, xml } from "@odoo/owl";

/** Client-side filter box for the mobile.feature User Access list; not bound to any field. */
export class UserAccessSearch extends Component {
    static template = xml`
        <div class="mb-2">
            <input type="text"
                   class="o_input"
                   style="max-width: 320px;"
                   placeholder="Search users..."
                   t-on-input="onInput"/>
        </div>`;
    static props = { "*": true };

    onInput(ev) {
        const term = (ev.target.value || "").trim().toLowerCase();
        // Limit the scope to the notebook page that contains this search box.
        const scope = ev.target.closest(".tab-pane") || document;
        const rows = scope.querySelectorAll(".o_list_table tbody tr.o_data_row");
        rows.forEach((row) => {
            const text = (row.textContent || "").toLowerCase();
            row.style.display = !term || text.includes(term) ? "" : "none";
        });
    }
}

registry.category("view_widgets").add("mobile_user_access_search", {
    component: UserAccessSearch,
});
