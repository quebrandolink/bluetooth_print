package com.example.bluetooth_print;

import android.util.Log;

import java.util.ArrayDeque;
import java.util.concurrent.*;


public class ThreadPool {

    private Runnable mActive;

    private static ThreadPool threadPool;
    /**
     * Conjunto de threads Java
     */
    private ThreadPoolExecutor threadPoolExecutor;

    /**
     * Número máximo de threads disponíveis no sistema
     */
    private final static int CPU_AVAILABLE = Runtime.getRuntime().availableProcessors();

    /**
     * Número máximo de threads
     */
    private final static int MAX_POOL_COUNTS = CPU_AVAILABLE * 2 + 1;

    /**
     * Tempo de vida da thread
     */
    private final static long AVAILABLE = 1L;

    /**
     * Número de threads
     */
    private final static int CORE_POOL_SIZE = CPU_AVAILABLE + 1;

    /**
     * Fila de threads
     */
    private BlockingQueue<Runnable> mWorkQueue = new ArrayBlockingQueue<>(CORE_POOL_SIZE);

    private ArrayDeque<Runnable> mArrayDeque = new ArrayDeque<>();

    private ThreadFactory threadFactory = new ThreadFactoryBuilder("ThreadPool");

    private ThreadPool() {
        threadPoolExecutor = new ThreadPoolExecutor(CORE_POOL_SIZE, MAX_POOL_COUNTS, AVAILABLE, TimeUnit.SECONDS, mWorkQueue,threadFactory);
    }

    public static ThreadPool getInstantiation() {
        if (threadPool == null) {
            threadPool = new ThreadPool();
        }
        return threadPool;
    }

    public void addParallelTask(Runnable runnable) { //Fios paralelos
        if (runnable == null) {
            throw new NullPointerException("addTask(Runnable runnable) passed in parameter is empty");
        }
        if (threadPoolExecutor.getActiveCount()<MAX_POOL_COUNTS) {
            Log.i("Lee","Currently there are"+threadPoolExecutor.getActiveCount()+" threads running, there are"+mWorkQueue.size()+" tasks waiting in queue");
          synchronized (this){
              threadPoolExecutor.execute(runnable);
          }
        }
    }
    public synchronized void addSerialTask(final Runnable r) { //Fios em série
        if (r == null) {
            throw new NullPointerException("addTask(Runnable runnable) passed in parameter is empty");
        }
        mArrayDeque.offer(new Runnable() {
            @Override
            public void run() {
                try {
                    r.run();
                } finally {
                    scheduleNext();
                }
            }
        });
        // Ao entrar na fila pela primeira vez, o mActivie está vazio, então você precisa chamar o método scheduleNext manualmente.
        if (mActive == null) {
            scheduleNext();
        }
    }
    private void scheduleNext() {
        if ((mActive = mArrayDeque.poll()) != null) {
            threadPoolExecutor.execute(mActive);
        }
    }

    public void stopThreadPool() {
        if (threadPoolExecutor != null) {
            threadPoolExecutor.shutdown();
            threadPoolExecutor = null;
            threadPool = null;
        }
    }
}