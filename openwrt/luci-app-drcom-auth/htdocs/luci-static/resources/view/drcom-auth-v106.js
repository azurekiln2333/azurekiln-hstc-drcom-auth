'use strict';
'require form';
'require fs';
'require view';
'require ui';

return view.extend({
	load: function() {
		return fs.exec_direct('/etc/init.d/drcom_auth', [ 'enabled' ]).catch(function() { return ''; });
	},

	render: function(data) {
		var m, s, o, compactStyle, lang, tr, toolbar;
		var isEnabled = data.trim() === 'enabled';
		var dict = {
			zh: {
				title: 'Dr.COM 认证',
				desc: '配置校园网认证与自动重连。',
				basic: '基础认证',
				network: '联网检测',
				ticket: '获取上网门票',
				ticketDone: '已执行获取上网门票。',
				enable: '启用联网检测',
				username: '账号',
				password: '密码',
				wanPort: 'WAN 接口',
				deviceType: '设备类型',
				pc: '电脑',
				mobile: '移动设备',
				interval: '两次联网间隔时间',
				intervalDesc: '两次联网检测之间的秒数。',
				pingHost: '检测主机',
				server: '服务器设置',
				serverIp: 'Dr.COM 服务器 IP',
				casUrl: 'CAS 地址',
				userAgent: 'User-Agent',
				langZh: '中文',
				langEn: 'English'
			},
			en: {
				title: 'Dr.COM Auth',
				desc: 'Configure campus network authentication and automatic reconnect.',
				basic: 'Authentication',
				network: 'Network Check',
				ticket: 'Get Internet Ticket',
				ticketDone: 'Internet ticket request executed.',
				enable: 'Enable Network Check',
				username: 'Username',
				password: 'Password',
				wanPort: 'WAN Interface',
				deviceType: 'Device Type',
				pc: 'PC',
				mobile: 'Mobile Device',
				interval: 'Check Interval',
				intervalDesc: 'Seconds between connectivity checks.',
				pingHost: 'Ping Host',
				server: 'Server Settings',
				serverIp: 'Dr.COM Server IP',
				casUrl: 'CAS URL',
				userAgent: 'User-Agent',
				langZh: '中文',
				langEn: 'English'
			}
		};

		lang = window.localStorage.getItem('drcom-auth-lang') || ((navigator.language || '').indexOf('zh') === 0 ? 'zh' : 'en');
		tr = function(key) {
			return dict[lang][key] || key;
		};

		toolbar = E('div', { 'class': 'drcom-auth-toolbar' }, [
			E('button', {
				'class': 'btn cbi-button' + (lang === 'zh' ? ' cbi-button-apply' : ''),
				'click': function() {
					window.localStorage.setItem('drcom-auth-lang', 'zh');
					window.location.reload();
				}
			}, tr('langZh')),
			E('button', {
				'class': 'btn cbi-button' + (lang === 'en' ? ' cbi-button-apply' : ''),
				'click': function() {
					window.localStorage.setItem('drcom-auth-lang', 'en');
					window.location.reload();
				}
			}, tr('langEn'))
		]);

		m = new form.Map('drcom_auth', tr('title'), tr('desc'));
		compactStyle = E('style', {}, [
			'.drcom-auth-view .cbi-map-descr{margin-bottom:10px}',
			'.drcom-auth-view .cbi-section{margin:10px 0 14px 0;padding:0;overflow:hidden}',
			'.drcom-auth-view .cbi-section h3{margin:0;padding:14px 16px 8px 16px}',
			'.drcom-auth-view .cbi-section-node{padding:20px 24px 22px 24px}',
			'.drcom-auth-view .cbi-value{clear:both;margin-bottom:8px!important;padding-top:1px!important;padding-bottom:1px!important}',
			'.drcom-auth-view .cbi-value:last-child{margin-bottom:0!important}',
			'.drcom-auth-view .cbi-value-field input,.drcom-auth-view .cbi-value-field select,.drcom-auth-view .cbi-value-field textarea,.drcom-auth-view .cbi-value-field .cbi-dropdown{margin-bottom:3px!important}',
			'.drcom-auth-view .cbi-value-field > *:last-child{margin-bottom:0!important}',
			'.drcom-auth-view .cbi-value-description{clear:both;margin-top:2px;margin-bottom:0}',
			'.drcom-auth-view .cbi-button{margin-bottom:3px}',
			'.drcom-auth-toolbar{display:flex;justify-content:flex-end;gap:8px;margin:0 0 8px 0}',
			'.drcom-auth-toolbar .btn{min-width:74px}'
		].join('\n'));

		s = m.section(form.TypedSection, 'drcom_auth', tr('basic'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Button, '_ticket', tr('ticket'));
		o.inputtitle = tr('ticket');
		o.inputstyle = 'apply';
		o.onclick = function() {
			return fs.exec('/etc/init.d/drcom_auth', [ 'ticket' ]).then(function() {
				ui.addNotification(null, E('p', tr('ticketDone')));
			}).catch(function(e) {
				ui.addNotification(null, E('p', e.message), 'error');
			});
		};

		o = s.option(form.Value, 'username', tr('username'));
		o.placeholder = '202400000000';
		o.rmempty = false;

		o = s.option(form.Value, 'password', tr('password'));
		o.password = true;
		o.rmempty = false;

		o = s.option(form.Value, 'wan_port', tr('wanPort'));
		o.placeholder = 'eth1';
		o.rmempty = false;

		o = s.option(form.ListValue, 'mac_type', tr('deviceType'));
		o.value('1', tr('pc'));
		o.value('2', tr('mobile'));
		o.default = '2';

		s = m.section(form.TypedSection, 'drcom_auth', tr('network'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', tr('enable'));
		o.default = isEnabled ? '1' : '0';
		o.rmempty = false;

		o = s.option(form.Value, 'check_interval', tr('interval'));
		o.datatype = 'uinteger';
		o.default = '60';
		o.rmempty = false;
		o.description = tr('intervalDesc');

		o = s.option(form.Value, 'ping_host', tr('pingHost'));
		o.placeholder = 'baidu.com';
		o.rmempty = false;

		s = m.section(form.TypedSection, 'drcom_auth', tr('server'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Value, 'drcom_server_ip', tr('serverIp'));
		o.datatype = 'ip4addr';
		o.placeholder = '192.168.2.34';
		o.rmempty = false;

		o = s.option(form.Value, 'hscas_url', tr('casUrl'));
		o.placeholder = 'https://hscas.hstc.edu.cn';
		o.rmempty = false;

		o = s.option(form.Value, 'user_agent', tr('userAgent'));
		o.rmempty = false;

		return m.render().then(function(map) {
			return E('div', { 'class': 'drcom-auth-view' }, [ compactStyle, toolbar, map ]);
		});
	}
});
