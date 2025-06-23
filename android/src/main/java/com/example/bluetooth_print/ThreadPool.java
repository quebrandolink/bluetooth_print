package com.example.bluetooth_print;

import android.util.Log;

import java.util.ArrayDeque;
import java.util.concurrent.*;

/**
 * Classe que implementa um gerenciador de pool de threads para execução
 * paralela e serial de tarefas
 * 
 * Projetado para otimizar o uso de recursos em dispositivos móveis, controlando
 * a quantidade máxima de threads baseado nos núcleos disponíveis do
 * processador.
 */
public class ThreadPool {

    private Runnable mActive; // Tarefa atualmente em execução (para fila serial)

    // Instância singleton do pool
    private static ThreadPool threadPool;

    // Executor principal do pool de threads
    private ThreadPoolExecutor threadPoolExecutor;

    // Número de núcleos disponíveis no processador
    private final static int CPU_AVAILABLE = Runtime.getRuntime().availableProcessors();

    // Número máximo de threads no pool (fórmula otimizada para Android)
    private final static int MAX_POOL_COUNTS = CPU_AVAILABLE * 2 + 1;

    // Tempo que threads ociosas permanecem vivas (em segundos)
    private final static long AVAILABLE = 1L;

    // Número base de threads no pool
    private final static int CORE_POOL_SIZE = CPU_AVAILABLE + 1;

    // Fila de tarefas paralelas
    private BlockingQueue<Runnable> mWorkQueue = new ArrayBlockingQueue<>(CORE_POOL_SIZE);

    // Fila de tarefas seriais (ArrayDeque para FIFO)
    private ArrayDeque<Runnable> mArrayDeque = new ArrayDeque<>();

    // Factory para criação de threads com nome padrão
    private ThreadFactory threadFactory = new ThreadFactoryBuilder("ThreadPool");

    /**
     * Construtor privado (padrão Singleton)
     */
    private ThreadPool() {
        threadPoolExecutor = new ThreadPoolExecutor(
                CORE_POOL_SIZE,
                MAX_POOL_COUNTS,
                AVAILABLE,
                TimeUnit.SECONDS,
                mWorkQueue,
                threadFactory);
    }

    /**
     * Obtém a instância única (Singleton) do pool
     * 
     * @return Instância do ThreadPool
     */
    public static ThreadPool getInstantiation() {
        if (threadPool == null) {
            threadPool = new ThreadPool();
        }
        return threadPool;
    }

    /**
     * Adiciona uma tarefa para execução paralela
     * 
     * @param runnable Tarefa a ser executada
     * @throws NullPointerException Se a tarefa for nula
     */
    public void addParallelTask(Runnable runnable) {
        if (runnable == null) {
            throw new NullPointerException("Parâmetro addTask(Runnable runnable) não pode ser nulo");
        }

        // Verifica se há capacidade para mais threads ativas
        if (threadPoolExecutor.getActiveCount() < MAX_POOL_COUNTS) {
            Log.i("ThreadPool", threadsAtivas() + ", " + tarefasNaFila());

            // Adiciona de forma thread-safe
            synchronized (this) {
                threadPoolExecutor.execute(runnable);
            }
        }
    }

    /**
     * Adiciona uma tarefa para execução serial (ordem FIFO)
     * 
     * @param r Tarefa a ser executada
     * @throws NullPointerException Se a tarefa for nula
     */
    public synchronized void addSerialTask(final Runnable r) {
        if (r == null) {
            throw new NullPointerException("Parâmetro addTask(Runnable runnable) não pode ser nulo");
        }

        // Empacota a tarefa para garantir o encadeamento serial
        mArrayDeque.offer(new Runnable() {
            @Override
            public void run() {
                try {
                    r.run();
                } finally {
                    scheduleNext(); // Chama a próxima tarefa ao finalizar
                }
            }
        });

        // Se não há tarefa ativa, inicia o processamento
        if (mActive == null) {
            scheduleNext();
        }
    }

    /**
     * Agenda a próxima tarefa serial na fila
     */
    private void scheduleNext() {
        if ((mActive = mArrayDeque.poll()) != null) {
            threadPoolExecutor.execute(mActive);
        }
    }

    /**
     * Encerra o pool de threads e libera recursos
     */
    public void stopThreadPool() {
        if (threadPoolExecutor != null) {
            threadPoolExecutor.shutdown();
            threadPoolExecutor = null;
            threadPool = null;
        }
    }

    // Métodos auxiliares para logs
    private String threadsAtivas() {
        return "Threads ativas: " + threadPoolExecutor.getActiveCount();
    }

    private String tarefasNaFila() {
        return "Tarefas na fila: " + mWorkQueue.size();
    }
}