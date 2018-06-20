set search_path = ret0;

select max(present_sessions) as max_ccu_across_all from node_stats where measured_at > now() - interval '1 week';
select max(max_occupant_count + 1) from hubs where inserted_at > now() - interval '1 week';

select (active_rooms / 7) as active_rooms_per_day, total_rooms, ((active_rooms * 1.0) / (total_rooms * 1.0)) * 100 as room_active_conversion_rate from (select count(*) as total_rooms, sum(case when max_occupant_count > 0 then 1 else 0 end) as active_rooms from hubs where inserted_at > now() - interval '1 week') a;

select day1.a, day2.a, day3.a, day4.a, day5.a, day6.a, day7.a, ((day1.a + day2.a + day3.a + day4.a + day5.a + day6.a + day7.a) / 7.0) as average_dau_last_week from
(select count(*) as a from session_stats where started_at > now() - interval '24 hours' and ((entered_event_payload->'isNewDaily')::varchar)::boolean) as day1,
(select count(*) as a from session_stats where started_at > now() - interval '48 hours' and started_at < now() - interval '24 hours' and ((entered_event_payload->'isNewDaily')::varchar)::boolean) as day2,
(select count(*) as a from session_stats where started_at > now() - interval '72 hours' and started_at < now() - interval '48 hours' and ((entered_event_payload->'isNewDaily')::varchar)::boolean) as day3,
(select count(*) as a from session_stats where started_at > now() - interval '96 hours' and started_at < now() - interval '72 hours' and ((entered_event_payload->'isNewDaily')::varchar)::boolean) as day4,
(select count(*) as a from session_stats where started_at > now() - interval '120 hours' and started_at < now() - interval '96 hours' and ((entered_event_payload->'isNewDaily')::varchar)::boolean) as day5,
(select count(*) as a from session_stats where started_at > now() - interval '144 hours' and started_at < now() - interval '120 hours' and ((entered_event_payload->'isNewDaily')::varchar)::boolean) as day6,
(select count(*) as a from session_stats where started_at > now() - interval '168 hours' and started_at < now() - interval '144 hours' and ((entered_event_payload->'isNewDaily')::varchar)::boolean) as day7;

select 
g.total_count as total_sessions,
(a.total_rift_session_time + b.total_openvr_session_time) as total_desktop_vr_time,
(c.total_gearvr_session_time + e.total_daydream_session_time + h.total_oculusgo_session_time) as total_mobile_vr_time,
f.avg_screen_session_time,
((a.avg_rift_session_time + b.avg_openvr_session_time) / 2) as desktop_vr_avg_session_time,
((c.avg_gearvr_session_time + e.avg_daydream_session_time + h.avg_oculusgo_session_time) / 3) as mobile_vr_avg_session_time,
((a.rift_count + b.openvr_count + c.gearvr_count + h.oculusgo_count + d.cardboard_count + e.daydream_count * 1.0) / g.total_count) * 100.0 as vr_device_rate,
((a.rift_count + b.openvr_count * 1.0) / g.total_count) * 100.0 as desktop_vr_rate,
((c.gearvr_count * 1.0 + e.daydream_count * 1.0 + h.oculusgo_count * 1.0) / g.total_count) * 100.0 as non_cardboard_mobile_rate,
((h.oculusgo_count * 1.0) / g.total_count) * 100.0 as standalone_rate,
a.avg_rift_session_time, 
b.avg_openvr_session_time, 
c.avg_gearvr_session_time, 
d.avg_cardboard_session_time, 
e.avg_daydream_session_time, 
h.avg_oculusgo_session_time, 
((d.cardboard_count * 1.0) / g.total_count) * 100.0 as cardboard_mobile_rate

from

	(select count(sessions.duration) as rift_count, sum(sessions.duration) as total_rift_session_time, avg(sessions.duration) as avg_rift_session_time from
	(select session_id, (entered_event_payload->'entryDisplayType')::varchar display, (ended_at - entered_event_received_at) duration from session_stats
		where entered_event_received_at > now() - interval '1 week' and (ended_at - entered_event_received_at) between interval '30 seconds' and interval '2 hours') as sessions
	where (sessions.display like '%Oculus VR HMD%')) as a,

	(select count(sessions.duration) as openvr_count, sum(sessions.duration) as total_openvr_session_time, avg(sessions.duration) as avg_openvr_session_time from
	(select session_id, (entered_event_payload->'entryDisplayType')::varchar display, (ended_at - entered_event_received_at) duration from session_stats
		where entered_event_received_at > now() - interval '1 week' and (ended_at - entered_event_received_at) between interval '30 seconds' and interval '2 hours') as sessions
	where (sessions.display like '%OpenVR HMD%')) as b,

	(select count(sessions.duration) as gearvr_count, sum(sessions.duration) as total_gearvr_session_time, avg(sessions.duration) as avg_gearvr_session_time from
	(select session_id, (entered_event_payload->'entryDisplayType')::varchar display, (ended_at - entered_event_received_at) duration from session_stats
		where entered_event_received_at > now() - interval '1 week' and (ended_at - entered_event_received_at) between interval '30 seconds' and interval '2 hours') as sessions
	where (sessions.display like '%Gear VR%')) as c,

	(select count(sessions.duration) as cardboard_count, sum(sessions.duration) as total_cardboard_session_time, avg(sessions.duration) as avg_cardboard_session_time from
	(select session_id, (entered_event_payload->'entryDisplayType')::varchar display, (ended_at - entered_event_received_at) duration from session_stats
		where entered_event_received_at > now() - interval '1 week' and (ended_at - entered_event_received_at) between interval '30 seconds' and interval '2 hours') as sessions
	where (sessions.display like '%Cardboard%')) as d,

	(select count(sessions.duration) as daydream_count, sum(sessions.duration) as total_daydream_session_time, avg(sessions.duration) as avg_daydream_session_time from
	(select session_id, (entered_event_payload->'entryDisplayType')::varchar display, (ended_at - entered_event_received_at) duration from session_stats
		where entered_event_received_at > now() - interval '1 week' and (ended_at - entered_event_received_at) between interval '30 seconds' and interval '2 hours') as sessions
	where (sessions.display like '%Daydream%')) as e,

	(select count(sessions.duration) as screen_count, sum(sessions.duration) as total_screen_session_time, avg(sessions.duration) as avg_screen_session_time from
	(select session_id, (entered_event_payload->'entryDisplayType')::varchar display, (ended_at - entered_event_received_at) duration from session_stats
		where entered_event_received_at > now() - interval '1 week' and (ended_at - entered_event_received_at) between interval '30 seconds' and interval '2 hours') as sessions
	where (sessions.display = '"Screen"')) as f,

	(select count(sessions.duration) as total_count, sum(sessions.duration) as total_session_time, avg(sessions.duration) as avg_total_session_time from
	(select session_id, (entered_event_payload->'entryDisplayType')::varchar display, (ended_at - entered_event_received_at) duration from session_stats
		where entered_event_received_at > now() - interval '1 week' and (ended_at - entered_event_received_at) between interval '30 seconds' and interval '2 hours') as sessions) as g,

	(select count(sessions.duration) as oculusgo_count, sum(sessions.duration) as total_oculusgo_session_time, avg(sessions.duration) as avg_oculusgo_session_time from
	(select session_id, (entered_event_payload->'entryDisplayType')::varchar display, (ended_at - entered_event_received_at) duration from session_stats
		where entered_event_received_at > now() - interval '1 week' and (ended_at - entered_event_received_at) between interval '30 seconds' and interval '2 hours') as sessions
	where (sessions.display = '"Oculus Go"')) as h;



