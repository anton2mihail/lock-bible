package com.john.bible.platform

import android.app.*
import android.content.*
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.*
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.john.bible.MainActivity
import com.john.bible.R
import com.john.bible.data.JohnStore
import com.john.bible.ui.ReaderSpeech

/** Keeps read-aloud active when Android backgrounds the app. */
class JohnPlaybackService:Service() {
    private val handler=Handler(Looper.getMainLooper())
    private lateinit var session:MediaSession
    private lateinit var speech:ReaderSpeech
    private val update=object:Runnable {
        override fun run() {
            if(!speech.active) { stopForeground(STOP_FOREGROUND_REMOVE);stopSelf();return }
            refresh()
            handler.postDelayed(this,1000)
        }
    }
    override fun onCreate() {
        super.onCreate()
        speech=ReaderSpeech.current() ?: ReaderSpeech.get(this,JohnStore(this))
        getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel("john_audio","Read aloud",NotificationManager.IMPORTANCE_LOW))
        session=MediaSession(this,"JohnReadAloud").apply {
            setCallback(object:MediaSession.Callback() {
                override fun onPlay(){speech.resume();refresh()}
                override fun onPause(){speech.pause();refresh()}
                override fun onSkipToNext(){speech.next();refresh()}
                override fun onSkipToPrevious(){speech.previous();refresh()}
                override fun onStop(){speech.stop();stopSelf()}
            })
            isActive=true
        }
        startForeground(200,notification())
        handler.post(update)
    }
    override fun onStartCommand(intent:Intent?,flags:Int,startId:Int):Int {
        when(intent?.action){"play"->speech.resume();"pause"->speech.pause();"next"->speech.next();"previous"->speech.previous();"stop"->{speech.stop();stopSelf()}}
        if(speech.active)refresh()
        return START_NOT_STICKY
    }
    private fun refresh() {
        session.setMetadata(MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE,"${speech.bookName} ${speech.chapter}:${speech.label}").putString(MediaMetadata.METADATA_KEY_ARTIST,"John 1:1 · Scripture & Prayer").build())
        session.setPlaybackState(PlaybackState.Builder().setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS or PlaybackState.ACTION_STOP).setState(if(speech.playing)PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,0,1f).build())
        getSystemService(NotificationManager::class.java).notify(200,notification())
    }
    private fun notification():Notification {
        val open=PendingIntent.getActivity(this,200,Intent(this,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        fun action(name:String)=PendingIntent.getService(this,name.hashCode(),Intent(this,JohnPlaybackService::class.java).setAction(name),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this,"john_audio").setSmallIcon(R.drawable.ic_notification).setContentTitle("${speech.bookName} ${speech.chapter}:${speech.label}").setContentText(if(speech.playing)"Reading aloud" else "Paused").setContentIntent(open).setOngoing(speech.playing).setSilent(true)
            .addAction(android.R.drawable.ic_media_previous,"Previous verse",action("previous"))
            .addAction(if(speech.playing)android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,if(speech.playing)"Pause" else "Play",action(if(speech.playing)"pause" else "play"))
            .addAction(android.R.drawable.ic_media_next,"Next verse",action("next"))
            .addAction(android.R.drawable.ic_menu_close_clear_cancel,"Stop",action("stop"))
            .setStyle(androidx.media.app.NotificationCompat.MediaStyle().setMediaSession(android.support.v4.media.session.MediaSessionCompat.Token.fromToken(session.sessionToken)).setShowActionsInCompactView(0,1,2)).build()
    }
    override fun onDestroy() {handler.removeCallbacksAndMessages(null);session.isActive=false;session.release();super.onDestroy()}
    override fun onBind(intent:Intent?):IBinder?=null
    companion object { fun start(context:Context) {ContextCompat.startForegroundService(context,Intent(context,JohnPlaybackService::class.java))} }
}
