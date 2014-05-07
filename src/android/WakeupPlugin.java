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

				saveToPrefs(cordova.getActivity().getApplicationContext(), options.getJSONArray("alarms"));
				
				setAlarms(cordova.getActivity().getApplicationContext(), options.getJSONArray("alarms"));

				WakeupPlugin.connectionCallbackContext = callbackContext;
				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);  

			}else{
				callbackContext.error(LOG_TAG + " error: invalid action (" + action + ")");
				ret=false;
			}
		} catch (JSONException e) {
			callbackContext.error(LOG_TAG + " error: invalid json");
			ret = false;
		} catch (Exception e) {
			callbackContext.error(LOG_TAG + " error: " + e.getMessage());
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
      WakeupPlugin.setAlarms( context, alarms);
    } catch (JSONException e) {
      e.printStackTrace();
    }
  }

	@SuppressLint({ "SimpleDateFormat", "NewApi" })
	protected static void setAlarms(Context context, JSONArray alarms) throws JSONException{

		cancelAlarms(context);

		for(int i=0;i<alarms.length();i++){
			JSONObject alarm=alarms.getJSONObject(i);
			if (!alarm.has("time") || !alarm.has("days")){
				throw new JSONException("Invalid alarm configuration: " + alarm.toString());
			}
			JSONArray days=alarm.getJSONArray("days");
			JSONObject time=alarm.getJSONObject("time");
			for (int j=0;j<days.length();j++){
				Calendar alarmDate=getAlarmDate(time, daysOfWeek.get(days.getString(j)));
				if(alarmDate!=null){
					SimpleDateFormat sdf=new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
					Log.d(LOG_TAG,"setting alarm at " + sdf.format(alarmDate.getTime()));

					Intent intent = new Intent(context, WakeupReceiver.class);
					if(alarm.has("extra")){
						intent.putExtra("extra", alarm.getJSONObject("extra").toString());
						intent.putExtra("time", time.toString());
						intent.putExtra("day", days.getString(j));
					}

					PendingIntent sender = PendingIntent.getBroadcast(context, 19999 + daysOfWeek.get(days.getString(j)), intent, PendingIntent.FLAG_UPDATE_CURRENT);
					AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
					if (Build.VERSION.SDK_INT>=19) {
						alarmManager.setExact(AlarmManager.RTC_WAKEUP, alarmDate.getTimeInMillis(), sender);
					} else {
						alarmManager.set(AlarmManager.RTC_WAKEUP, alarmDate.getTimeInMillis(), sender);
					}
				}
			}
		}
	}


	protected static void cancelAlarms(Context context){
		Log.d(LOG_TAG, "canceling alarms");
		for (int i=0;i<7;i++){
			Intent intent = new Intent(context, WakeupReceiver.class);
			PendingIntent sender = PendingIntent.getBroadcast(context, 19999+i, intent, PendingIntent.FLAG_UPDATE_CURRENT);
			AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
			alarmManager.cancel(sender);
		}
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

	protected static void saveToPrefs(Context context, JSONArray alarms) {
		SharedPreferences prefs;
		SharedPreferences.Editor editor;

		prefs = PreferenceManager.getDefaultSharedPreferences(context);
		editor = prefs.edit();
		editor.putString("alarms", alarms.toString());
		editor.commit();

	}

}
