package org.nypr.cordova.wakeupplugin;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.GregorianCalendar;
import java.util.HashMap;
import java.util.Map;
import java.util.TimeZone;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.Context;
import android.content.SharedPreferences;
import android.annotation.SuppressLint;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.os.Build;
import android.preference.PreferenceManager;
import android.util.Log;

public class WakeupPlugin extends CordovaPlugin {

	protected static final String LOG_TAG = "WakeupPlugin";

	protected static final int ID_DAYLIST_OFFSET = 10010;
	protected static final int ID_ONETIME_OFFSET = 10000;
	protected static final int ID_SNOOZE_OFFSET = 10001;
	
	public static  Map<String , Integer> daysOfWeek = new HashMap<String , Integer>() {
		private static final long serialVersionUID = 1L;
		{
			put("sunday", 0);
			put("monday", 1);
			put("tuesday", 2);
			put("wednesday", 3);
			put("thursday", 4);
			put("friday", 5);
			put("saturday", 6);
		}
	};

	public static CallbackContext connectionCallbackContext;

  @Override
  public void onReset() {
	// app startup
    Log.d(LOG_TAG, "Wakeup Plugin onReset");
    if (! cordova.getActivity().getIntent().getExtras().getBoolean("wakeup", false)) {
      setAlarmsFromPrefs( cordova.getActivity().getApplicationContext() );
    }
    super.onReset();
  }

	@Override
	public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
		boolean ret=true;
		try {
			if(action.equalsIgnoreCase("wakeup")) {
				JSONObject options=args.getJSONObject(0);

				JSONArray alarms;
				if (options.has("alarms")==true) {
					alarms = options.getJSONArray("alarms");
				} else {
					alarms = new JSONArray(); // default to empty array
				}
				
				saveToPrefs(cordova.getActivity().getApplicationContext(), alarms);
				setAlarms(cordova.getActivity().getApplicationContext(), alarms, true);

				WakeupPlugin.connectionCallbackContext = callbackContext;
				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);  
			}else if(action.equalsIgnoreCase("snooze")) {
				JSONObject options=args.getJSONObject(0);

				if (options.has("alarms")==true) {
					Log.d(LOG_TAG, "scheduling snooze...");
					JSONArray alarms = options.getJSONArray("alarms");
					setAlarms(cordova.getActivity().getApplicationContext(), alarms, false);
				}
						
				WakeupPlugin.connectionCallbackContext = callbackContext;
				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);  
			}else{
				PluginResult pluginResult = new PluginResult(PluginResult.Status.ERROR, LOG_TAG + " error: invalid action (" + action + ")");
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);  
				ret=false;
			}
		} catch (JSONException e) {
			PluginResult pluginResult = new PluginResult(PluginResult.Status.ERROR, LOG_TAG + " error: invalid json");
			pluginResult.setKeepCallback(true);
			callbackContext.sendPluginResult(pluginResult);  
			ret = false;
		} catch (Exception e) {
			PluginResult pluginResult = new PluginResult(PluginResult.Status.ERROR, LOG_TAG + " error: " + e.getMessage());
			pluginResult.setKeepCallback(true);
			callbackContext.sendPluginResult(pluginResult);  
			ret = false;
		}
		return ret;
	}

  public static void setAlarmsFromPrefs(Context context) {
    try {
      SharedPreferences prefs;
      prefs = PreferenceManager.getDefaultSharedPreferences(context);
      String a = prefs.getString("alarms", "[]");
      Log.d(LOG_TAG, "setting alarms:\n" + a);
      JSONArray alarms = new JSONArray( a );
      WakeupPlugin.setAlarms(context, alarms, true);
    } catch (JSONException e) {
      e.printStackTrace();
    }
  }

	@SuppressLint({ "SimpleDateFormat", "NewApi" })
	protected static void setAlarms(Context context, JSONArray alarms, boolean cancelAlarms) throws JSONException{

		if (cancelAlarms) {
			cancelAlarms(context);
		}

		for(int i=0;i<alarms.length();i++){
			JSONObject alarm=alarms.getJSONObject(i);
			
			String type = "onetime";
			if (alarm.has("type")){
				type = alarm.getString("type");
			}
			
			if (!alarm.has("time")){
				throw new JSONException("alarm missing time: " + alarm.toString());
			}
			
			JSONObject time=alarm.getJSONObject("time");
			
			if ( type.equals("onetime")) {
				Calendar alarmDate=getOneTimeAlarmDate(time);
				Intent intent = new Intent(context, WakeupReceiver.class);
				if(alarm.has("extra")){
					intent.putExtra("extra", alarm.getJSONObject("extra").toString());
					intent.putExtra("type", type);
				}
				
				setNotification(context, type, alarmDate, intent, ID_ONETIME_OFFSET);
				
			} else if ( type.equals("daylist") ) {
				JSONArray days=alarm.getJSONArray("days");
				
				for (int j=0;j<days.length();j++){
					Calendar alarmDate=getAlarmDate(time, daysOfWeek.get(days.getString(j)));
					Intent intent = new Intent(context, WakeupReceiver.class);
					if(alarm.has("extra")){
						intent.putExtra("extra", alarm.getJSONObject("extra").toString());
						intent.putExtra("type", type);
						intent.putExtra("time", time.toString());
						intent.putExtra("day", days.getString(j));
					}
					
					setNotification(context, type, alarmDate, intent, ID_DAYLIST_OFFSET + daysOfWeek.get(days.getString(j)));
				}
			} else if ( type.equals("snooze") ) {
				cancelSnooze(context);
				Calendar alarmDate=getTimeFromNow(time);
				Intent intent = new Intent(context, WakeupReceiver.class);
				if(alarm.has("extra")){
					intent.putExtra("extra", alarm.getJSONObject("extra").toString());
					intent.putExtra("type", type);
				}
				setNotification(context, type, alarmDate, intent, ID_SNOOZE_OFFSET);
			}
		}
	}


	protected static void setNotification(Context context, String type, Calendar alarmDate, Intent intent, int id) throws JSONException{
		if(alarmDate!=null){
			SimpleDateFormat sdf=new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
			Log.d(LOG_TAG,"setting alarm at " + sdf.format(alarmDate.getTime()) + "; id " + id);
			
			intent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
			PendingIntent sender = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT);
			AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
			if (Build.VERSION.SDK_INT>=19) {
				alarmManager.setExact(AlarmManager.RTC_WAKEUP, alarmDate.getTimeInMillis(), sender);
			} else {
				alarmManager.set(AlarmManager.RTC_WAKEUP, alarmDate.getTimeInMillis(), sender);
			}
			
			if(WakeupPlugin.connectionCallbackContext!=null) {
				JSONObject o=new JSONObject();
				o.put("type", "set");
				o.put("alarm_type", type);
				o.put("alarm_date", alarmDate.getTimeInMillis());
				
				Log.d(LOG_TAG, "alarm time in millis: " + alarmDate.getTimeInMillis());
				
				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, o);
				pluginResult.setKeepCallback(true);
				WakeupPlugin.connectionCallbackContext.sendPluginResult(pluginResult);  
			}
		}
	}
	
	protected static void cancelAlarms(Context context){
		Log.d(LOG_TAG, "canceling alarms");
		Intent intent = new Intent(context, WakeupReceiver.class);
		PendingIntent sender = PendingIntent.getBroadcast(context, ID_ONETIME_OFFSET, intent, PendingIntent.FLAG_UPDATE_CURRENT);
		AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
		Log.d(LOG_TAG, "cancelling alarm id " + ID_ONETIME_OFFSET);
		alarmManager.cancel(sender);
		
		cancelSnooze(context);
		
		for (int i=0;i<7;i++){
			intent = new Intent(context, WakeupReceiver.class);
			Log.d(LOG_TAG, "cancelling alarm id " + (ID_DAYLIST_OFFSET+i));
			sender = PendingIntent.getBroadcast(context, ID_DAYLIST_OFFSET + i, intent, PendingIntent.FLAG_UPDATE_CURRENT);
			alarmManager.cancel(sender);
		}
	}

	protected static void cancelSnooze(Context context){
		Log.d(LOG_TAG, "canceling snooze");
		Intent intent = new Intent(context, WakeupReceiver.class);
		PendingIntent sender = PendingIntent.getBroadcast(context, ID_SNOOZE_OFFSET, intent, PendingIntent.FLAG_UPDATE_CURRENT);
		AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
		Log.d(LOG_TAG, "cancelling alarm id " + ID_SNOOZE_OFFSET);
		alarmManager.cancel(sender);
	}
	
	protected static Calendar getOneTimeAlarmDate( JSONObject time) throws JSONException {
		TimeZone defaultz = TimeZone.getDefault();
		Calendar calendar = new GregorianCalendar(defaultz);
		Calendar now = new GregorianCalendar(defaultz);
		now.setTime(new Date());
		calendar.setTime(new Date());

		int hour=(time.has("hour")) ? time.getInt("hour") : -1;
		int minute=(time.has("minute")) ? time.getInt("minute") : 0;

		if(hour>=0){
			calendar.set(Calendar.HOUR_OF_DAY, hour);
			calendar.set(Calendar.MINUTE, minute);
			calendar.set(Calendar.SECOND, 0);
			calendar.set(Calendar.MILLISECOND,0);

			if (calendar.before(now)){
				calendar.set(Calendar.DATE, calendar.get(Calendar.DATE) + 1);
			}
		}else{
			calendar=null;
		}

		return calendar;
	}
	
	protected static Calendar getAlarmDate( JSONObject time, int dayOfWeek) throws JSONException {
		TimeZone defaultz = TimeZone.getDefault();
		Calendar calendar = new GregorianCalendar(defaultz);
		Calendar now = new GregorianCalendar(defaultz);
		now.setTime(new Date());
		calendar.setTime(new Date());

		int hour=(time.has("hour")) ? time.getInt("hour") : -1;
		int minute=(time.has("minute")) ? time.getInt("minute") : 0;

		if(hour>=0){
			calendar.set(Calendar.HOUR_OF_DAY, hour);
			calendar.set(Calendar.MINUTE, minute);
			calendar.set(Calendar.SECOND, 0);
			calendar.set(Calendar.MILLISECOND,0);

			int currentDayOfWeek=calendar.get(Calendar.DAY_OF_WEEK); // 1-7 = Sunday-Saturday
			currentDayOfWeek--; // make zero-based

			// add number of days until 'dayOfWeek' occurs
			int daysUntilAlarm=0;
			if(currentDayOfWeek>dayOfWeek){
				// currentDayOfWeek=thursday (4); alarm=monday (1) -- add 4 days
				daysUntilAlarm=(6-currentDayOfWeek) + dayOfWeek + 1; // (days until the end of week) + dayOfWeek + 1
			}else if(currentDayOfWeek<dayOfWeek){
				// example: currentDayOfWeek=monday (1); dayOfWeek=thursday (4) -- add three days
				daysUntilAlarm=dayOfWeek-currentDayOfWeek;
			}else{
				if(now.after(calendar.getTime())){
					daysUntilAlarm=7;
				}else{
					daysUntilAlarm=0;
				}
			}

			calendar.set(Calendar.DATE, now.get(Calendar.DATE) + daysUntilAlarm);
		}else{
			calendar=null;
		}

		return calendar;
	}

	protected static Calendar getTimeFromNow( JSONObject time) throws JSONException {
		TimeZone defaultz = TimeZone.getDefault();
		Calendar calendar = new GregorianCalendar(defaultz);
		calendar.setTime(new Date());

		int seconds=(time.has("seconds")) ? time.getInt("seconds") : -1;
		
		if(seconds>=0){
			calendar.add(Calendar.SECOND, seconds);
		}else{
			calendar=null;
		}

		return calendar;
	}
	
	protected static void saveToPrefs(Context context, JSONArray alarms) {
		SharedPreferences prefs;
		SharedPreferences.Editor editor;
	
		prefs = PreferenceManager.getDefaultSharedPreferences(context);
		editor = prefs.edit();
		editor.putString("alarms", alarms.toString());
		editor.commit();

	}

}
