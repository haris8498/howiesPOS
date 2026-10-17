const fs = require('fs');
const actions = ['View', 'Add', 'Edit', 'Delete'];
const modules = [
  { key: 'tables', name: 'Tables' },
  { key: 'menu', name: 'Menu Catalog' },
  { key: 'stock', name: 'Stock Catalog' },
  { key: 'users', name: 'Users' },
  { key: 'expenses', name: 'Expenses' },
];
let code = `export interface DefaultPermissionDefinition {
  id: string;
  role: 'manager' | 'cashier';
  module_name: string;
  action_name: string;
  description: string;
  is_granted: boolean;
  is_sensitive: boolean;
}\n\n`;

function generateRole(role) {
  let res = `export const INITIAL_${role.toUpperCase()}_PERMISSIONS: DefaultPermissionDefinition[] = [\n`;
  
  const specialModules = [
    { key: 'pos', name: 'POS Billing', actions: [{ id: 'mod_pos', action: 'Allow Access to POS Sales', desc: 'Access POS terminal and billing' }] },
    { key: 'online_orders', name: 'Online Orders', actions: [
        { id: 'mod_online_orders', action: 'Allow Access to Online Orders', desc: 'View online orders' },
        { id: 'online_orders_accept', action: 'Accept/Reject Orders', desc: 'Accept or reject customer orders' }
    ]},
    { key: 'takeaway', name: 'Takeaway Counter', actions: [
        { id: 'mod_takeaway', action: 'Allow Access to Takeaway', desc: 'View takeaway orders' },
        { id: 'takeaway_create', action: 'Create Takeaway Orders', desc: 'Punch new takeaway orders' }
    ]},
    { key: 'delivery', name: 'Delivery Tracking', actions: [
        { id: 'mod_delivery', action: 'Allow Access to Delivery', desc: 'View delivery tracking' },
        { id: 'del_assign', action: 'Assign Riders', desc: 'Assign riders to orders' }
    ]},
    { key: 'stock_in_out', name: 'Stock In / Out', actions: [
        { id: 'mod_stock_in_out', action: 'Allow Access to Stock In / Out', desc: 'View stock transactions' },
        { id: 'stock_in_action', action: 'Perform Stock In', desc: 'Add inward stock' },
        { id: 'stock_out_action', action: 'Perform Stock Out', desc: 'Record wastage or out' }
    ]},
    { key: 'reports', name: 'Reports', actions: [
        { id: 'mod_reports', action: 'Allow Access to Reports', desc: 'View reports' },
        { id: 'rep_export', action: 'Export Reports', desc: 'Export PDF & Excel' }
    ]}
  ];

  for (const mod of specialModules) {
    for (const act of mod.actions) {
      const granted = role === 'manager' || act.id.startsWith('mod_');
      const sensitive = act.action.includes('Delete') || act.id === 'mod_reports';
      res += `  { id: '${act.id}', role: '${role}', module_name: '${mod.name}', action_name: '${act.action}', description: '${act.desc}', is_granted: ${granted}, is_sensitive: ${sensitive} },\n`;
    }
  }

  for (const mod of modules) {
    for (const act of actions) {
      let id = act === 'View' ? `mod_${mod.key}` : `${mod.key}_${act.toLowerCase()}`;
      let actionName = act === 'View' ? `Allow Access to ${mod.name}` : `${act} ${mod.name}`;
      let desc = `${act} operations for ${mod.name}`;
      let granted = role === 'manager' || act === 'View';
      let sensitive = act === 'Delete' || (act === 'Edit' && mod.key === 'users');
      res += `  { id: '${id}', role: '${role}', module_name: '${mod.name}', action_name: '${actionName}', description: '${desc}', is_granted: ${granted}, is_sensitive: ${sensitive} },\n`;
    }
    if (mod.key === 'users') {
       res += `  { id: 'users_salary_disburse', role: '${role}', module_name: '${mod.name}', action_name: 'Mark Salary Paid', description: 'Disburse payroll', is_granted: ${role === 'manager'}, is_sensitive: true },\n`;
    }
  }

  res += '];\n\n';
  return res;
}

code += generateRole('manager');
code += generateRole('cashier');

fs.writeFileSync('src/common/rbac/constants/permissions.constants.ts', code);
console.log('Done generating permissions');
