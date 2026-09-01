package tools.samsung.tv2mreceiver;

import android.app.Activity;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.Window;
import android.view.WindowManager;

import java.io.BufferedReader;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.InetSocketAddress;
import java.net.Socket;

public final class MainActivity extends Activity
        implements SurfaceHolder.Callback,
        MediaPlayer.OnPreparedListener,
        MediaPlayer.OnErrorListener,
        MediaPlayer.OnCompletionListener {

    private static final String TAG = "SamsungTv2MReceiver";

    private MediaPlayer player;
    private volatile Socket mccpSocket;
    private boolean preparing;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(
                WindowManager.LayoutParams.FLAG_FULLSCREEN
                        | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                        | WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                        | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                        | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);

        SurfaceView surface = new SurfaceView(this);
        surface.getHolder().addCallback(this);
        setContentView(surface);
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        if (preparing) {
            return;
        }

        Uri data = getIntent().getData();
        if (data == null || data.getHost() == null || data.getPort() < 0) {
            writeStatus("error: missing WFD URI");
            finish();
            return;
        }

        preparing = true;
        player = new MediaPlayer();
        player.setDisplay(holder);
        player.setScreenOnWhilePlaying(true);
        player.setOnPreparedListener(this);
        player.setOnErrorListener(this);
        player.setOnCompletionListener(this);

        String uri = data.toString();
        Log.i(TAG, "Preparing " + uri);
        writeStatus("preparing");
        startMccp(data);
        try {
            player.setDataSource(uri);
            player.prepareAsync();
        } catch (IOException | RuntimeException error) {
            Log.e(TAG, "Unable to prepare WFD source", error);
            writeStatus("error: " + error.getClass().getSimpleName());
            finish();
        }
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        releasePlayer();
    }

    @Override
    public void onPrepared(MediaPlayer mediaPlayer) {
        Log.i(TAG, "WFD media prepared; starting playback");
        writeStatus("playing");
        mediaPlayer.start();
    }

    @Override
    public boolean onError(MediaPlayer mediaPlayer, int what, int extra) {
        Log.e(TAG, "MediaPlayer error what=" + what + " extra=" + extra);
        writeStatus("error: MediaPlayer what=" + what + " extra=" + extra);
        finish();
        return true;
    }

    @Override
    public void onCompletion(MediaPlayer mediaPlayer) {
        Log.i(TAG, "WFD playback completed");
        writeStatus("completed");
        finish();
    }

    @Override
    protected void onDestroy() {
        releasePlayer();
        super.onDestroy();
    }

    private void releasePlayer() {
        if (player != null) {
            player.reset();
            player.release();
            player = null;
        }
        preparing = false;
        closeMccp();
    }

    private void startMccp(final Uri uri) {
        final String host = uri.getHost();
        final int port = uri.getPort() + 1;

        new Thread(new Runnable() {
            @Override
            public void run() {
                for (int attempt = 0; attempt < 100 && mccpSocket == null; attempt++) {
                    Socket candidate = new Socket();
                    try {
                        candidate.connect(new InetSocketAddress(host, port), 1000);
                        mccpSocket = candidate;

                        PrintWriter writer = new PrintWriter(
                                candidate.getOutputStream(),
                                true);
                        writer.print(
                                "VERSION MCCP/1.1 Seq=0\r\n"
                                        + "mccp_version=1.2 device_type=mobile\r\n"
                                        + "\r\n");
                        writer.flush();
                        Log.i(TAG, "MCCP connected to " + host + ":" + port);

                        BufferedReader reader = new BufferedReader(
                                new InputStreamReader(candidate.getInputStream()));
                        char[] buffer = new char[512];
                        while (!candidate.isClosed()) {
                            int count = reader.read(buffer);
                            if (count < 0) {
                                break;
                            }
                            if (count > 0) {
                                Log.d(TAG, "MCCP received " + new String(buffer, 0, count));
                            }
                        }
                        return;
                    } catch (IOException error) {
                        try {
                            candidate.close();
                        } catch (IOException ignored) {
                        }
                        try {
                            Thread.sleep(100);
                        } catch (InterruptedException interrupted) {
                            Thread.currentThread().interrupt();
                            return;
                        }
                    }
                }
                Log.w(TAG, "MCCP connection was not established");
            }
        }, "Samsung TV MCCP").start();
    }

    private void closeMccp() {
        Socket socket = mccpSocket;
        mccpSocket = null;
        if (socket == null) {
            return;
        }
        try {
            socket.close();
        } catch (IOException error) {
            Log.w(TAG, "Unable to close MCCP socket", error);
        }
    }

    private void writeStatus(String status) {
        try (FileOutputStream output = openFileOutput("status", MODE_PRIVATE)) {
            output.write(status.getBytes("UTF-8"));
        } catch (IOException error) {
            Log.e(TAG, "Unable to write receiver status", error);
        }
    }
}
