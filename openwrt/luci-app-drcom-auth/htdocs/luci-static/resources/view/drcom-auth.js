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
		var m, s, o, compactStyle;
		var isEnabled = data[0].trim() === 'enabled';
		var isRunning = data[1].trim() === 'running';

		m = new form.Map('drcom_auth', _('Dr.COM Auth'), _('Configure HSTC Dr.COM campus network authentication and automatic reconnect.'));
		compactStyle = E('style', {}, [
			'.drcom-auth-view .cbi-map-descr{margin-bottom:.75rem}',
			'.drcom-auth-view .cbi-section{margin-top:.75rem;margin-bottom:.75rem}',
			'.drcom-auth-view .cbi-section h3{margin-top:0;margin-bottom:.5rem}',
			'.drcom-auth-view .cbi-value{padding-top:.35rem;padding-bottom:.35rem}',
			'.drcom-auth-view .cbi-value-description{margin-top:.15rem}'
		].join('\n'));

		s = m.section(form.TypedSection, 'drcom_auth', _('Basic Settings'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.DummyValue, '_status', _('Status'));
		o.rawhtml = true;
		o.cfgvalue = function() {
			return '<span id="drcom-auth-status">' + (isRunning ? _('Running') : _('Stopped')) + '</span>';
		};

		o = s.option(form.Button, '_restart', _('Restart'));
		o.inputtitle = _('Restart');
		o.inputstyle = 'apply';
		o.onclick = function() {
			return fs.exec('/etc/init.d/drcom_auth', [ 'restart' ]).then(function() {
				ui.addNotification(null, E('p', _('Service restarted.')));
			}).catch(function(e) {
				ui.addNotification(null, E('p', e.message), 'error');
			});
		};

		poll.add(function() {
			return fs.exec_direct('/etc/init.d/drcom_auth', [ 'running' ]).then(function(res) {
				var node = document.getElementById('drcom-auth-status');
				if (node)
					node.textContent = res.trim() === 'running' ? _('Running') : _('Stopped');
			}).catch(function() {});
		}, 5);

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

		o = s.option(form.ListValue, 'mac_type', _('Device Type'));
		o.value('1', _('PC'));
		o.value('2', _('Mobile Device'));
		o.default = '2';

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

		return m.render().then(function(map) {
			return E('div', { 'class': 'drcom-auth-view' }, [ compactStyle, map ]);
		});
	}
});
