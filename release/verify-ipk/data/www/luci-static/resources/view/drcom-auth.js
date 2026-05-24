'use strict';
'require form';
'require fs';
'require poll';
'require view';
'require ui';

return view.extend({
	load: function() {
		return Promise.all([
			fs.exec_direct('/etc/init.d/drcom_auth', [ 'enabled' ]).catch(function() { return ''; }),
			fs.exec_direct('/etc/init.d/drcom_auth', [ 'running' ]).catch(function() { return ''; })
		]);
	},

	render: function(data) {
		var m, s, o, status;
		var isEnabled = data[0].trim() === 'enabled';
		var isRunning = data[1].trim() === 'running';

		m = new form.Map('drcom_auth', _('Dr.COM Auth'), _('Configure HSTC Dr.COM campus network authentication and automatic reconnect.'));

		status = E('div', { 'class': 'cbi-section' }, [
			E('h3', _('Service Status')),
			E('p', { 'id': 'drcom-auth-status' }, isRunning ? _('Running') : _('Stopped')),
			E('div', { 'class': 'right' }, [
				E('button', {
					'class': 'btn cbi-button cbi-button-apply',
					'click': ui.createHandlerFn(this, function() {
						return fs.exec('/etc/init.d/drcom_auth', [ 'restart' ]).then(function() {
							ui.addNotification(null, E('p', _('Service restarted.')));
						}).catch(function(e) {
							ui.addNotification(null, E('p', e.message), 'error');
						});
					})
				}, _('Restart'))
			])
		]);

		poll.add(function() {
			return fs.exec_direct('/etc/init.d/drcom_auth', [ 'running' ]).then(function(res) {
				var node = document.getElementById('drcom-auth-status');
				if (node)
					node.textContent = res.trim() === 'running' ? _('Running') : _('Stopped');
			}).catch(function() {});
		}, 5);

		s = m.section(form.TypedSection, 'drcom_auth', _('Basic Settings'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.default = isEnabled ? '1' : '0';
		o.rmempty = false;

		o = s.option(form.Value, 'username', _('Username'));
		o.placeholder = '202400000000';
		o.rmempty = false;

		o = s.option(form.Value, 'password', _('Password'));
		o.password = true;
		o.rmempty = false;

		o = s.option(form.Value, 'wan_port', _('WAN Interface'));
		o.placeholder = 'eth1';
		o.rmempty = false;

		o = s.option(form.Value, 'check_interval', _('Check Interval'));
		o.datatype = 'uinteger';
		o.default = '60';
		o.rmempty = false;
		o.description = _('Seconds between connectivity checks.');

		o = s.option(form.Value, 'ping_host', _('Ping Host'));
		o.placeholder = 'baidu.com';
		o.rmempty = false;

		s = m.section(form.TypedSection, 'drcom_auth', _('Server Settings'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Value, 'drcom_server_ip', _('Dr.COM Server IP'));
		o.datatype = 'ip4addr';
		o.placeholder = '192.168.2.34';
		o.rmempty = false;

		o = s.option(form.Value, 'hscas_url', _('CAS URL'));
		o.placeholder = 'https://hscas.hstc.edu.cn';
		o.rmempty = false;

		o = s.option(form.Value, 'user_agent', _('User-Agent'));
		o.rmempty = false;

		s = m.section(form.TypedSection, 'drcom_auth', _('Portal Parameters'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Value, 'term_mac', _('Terminal MAC'));
		o.placeholder = 'AA:BB:CC:DD:EE:FF';
		o.rmempty = false;

		o = s.option(form.Value, 'wlan_ac_ip', _('WLAN AC IP'));
		o.placeholder = '10.10.10.10';
		o.rmempty = false;

		o = s.option(form.Value, 'wlan_ac_name', _('WLAN AC Name'));
		o.placeholder = 'AC001';
		o.rmempty = false;

		o = s.option(form.ListValue, 'login_method', _('Login Method'));
		o.value('1', '1');
		o.value('2', '2');
		o.default = '1';

		o = s.option(form.ListValue, 'mac_type', _('Device Type'));
		o.value('1', _('PC'));
		o.value('2', _('Mobile Device'));
		o.default = '2';

		o = s.option(form.ListValue, 'authex_enable', _('Authex Enable'));
		o.value('1', _('Enabled'));
		o.value('0', _('Disabled'));
		o.default = '1';

		o = s.option(form.Value, 'js_version', _('JS Version'));
		o.placeholder = '4.X';
		o.rmempty = false;

		return m.render().then(function(map) {
			return E([], [ status, map ]);
		});
	}
});
