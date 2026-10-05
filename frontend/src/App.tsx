import { useEffect, useState, type FormEvent } from "react";
import { api, type Task } from "./api";
import { useTheme } from "./useTheme";

export default function App() {
  const { theme, toggle } = useTheme();
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [title, setTitle] = useState("");
  const [creating, setCreating] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editingValue, setEditingValue] = useState("");

  useEffect(() => {
    void load();
  }, []);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      setTasks(await api.list());
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error cargando tareas");
    } finally {
      setLoading(false);
    }
  }

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    const value = title.trim();
    if (!value) return;
    setCreating(true);
    try {
      const task = await api.create(value);
      setTasks((prev) => [task, ...prev]);
      setTitle("");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error creando la tarea");
    } finally {
      setCreating(false);
    }
  }

  async function onToggle(task: Task) {
    try {
      const updated = await api.update(task.id, { completed: !task.completed });
      setTasks((prev) => prev.map((t) => (t.id === task.id ? updated : t)));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error actualizando");
    }
  }

  async function onSaveEdit(task: Task) {
    const next = editingValue.trim();
    if (!next || next === task.title) {
      setEditingId(null);
      return;
    }
    try {
      const updated = await api.update(task.id, { title: next });
      setTasks((prev) => prev.map((t) => (t.id === task.id ? updated : t)));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error actualizando");
    } finally {
      setEditingId(null);
    }
  }

  async function onDelete(id: string) {
    try {
      await api.remove(id);
      setTasks((prev) => prev.filter((t) => t.id !== id));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error borrando");
    }
  }

  const pending = tasks.filter((t) => !t.completed).length;

  return (
    <div className="min-h-full">
      <div className="mx-auto max-w-2xl px-6 py-10 sm:py-16">
        <header className="flex items-start justify-between gap-4 mb-10">
          <div>
            <h1 className="font-display text-4xl sm:text-5xl font-bold tracking-tight text-neutral-900 dark:text-neutral-50">
              Tareas
            </h1>
            <p className="mt-2 text-sm text-neutral-500 dark:text-neutral-400">
              Serverless · AWS Lambda + DynamoDB
            </p>
          </div>
          <button
            onClick={toggle}
            aria-label="Cambiar tema"
            className="rounded-full border border-neutral-200 dark:border-neutral-800 bg-white dark:bg-neutral-900 w-10 h-10 flex items-center justify-center text-lg hover:border-neutral-400 dark:hover:border-neutral-600 transition"
          >
            {theme === "dark" ? "☀" : "☾"}
          </button>
        </header>

        <form onSubmit={onCreate} className="flex gap-2 mb-6">
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="¿Qué hay que hacer?"
            className="flex-1 rounded-lg border border-neutral-200 dark:border-neutral-800 bg-white dark:bg-neutral-900 px-4 py-3 text-base outline-none focus:border-neutral-900 dark:focus:border-neutral-200 transition"
          />
          <button
            type="submit"
            disabled={creating || !title.trim()}
            className="rounded-lg bg-neutral-900 dark:bg-neutral-100 text-white dark:text-neutral-900 px-5 py-3 font-medium disabled:opacity-40 hover:opacity-90 transition"
          >
            Añadir
          </button>
        </form>

        {error && (
          <div className="mb-4 rounded-lg border border-red-300 bg-red-50 dark:border-red-900 dark:bg-red-950/40 px-4 py-3 text-sm text-red-800 dark:text-red-300">
            {error}
          </div>
        )}

        <div className="flex items-center justify-between text-xs uppercase tracking-wider text-neutral-500 dark:text-neutral-400 mb-3 px-1">
          <span>{tasks.length} totales · {pending} pendientes</span>
          <button
            onClick={() => void load()}
            className="hover:text-neutral-900 dark:hover:text-neutral-100 transition"
          >
            Recargar
          </button>
        </div>

        <ul className="divide-y divide-neutral-200 dark:divide-neutral-800 rounded-xl border border-neutral-200 dark:border-neutral-800 bg-white dark:bg-neutral-900 overflow-hidden">
          {loading && (
            <li className="px-4 py-6 text-center text-sm text-neutral-500">
              Cargando…
            </li>
          )}
          {!loading && tasks.length === 0 && (
            <li className="px-4 py-10 text-center text-sm text-neutral-500">
              Sin tareas todavía. Crea la primera arriba.
            </li>
          )}
          {tasks.map((t) => (
            <li
              key={t.id}
              className="group flex items-center gap-3 px-4 py-3 hover:bg-neutral-50 dark:hover:bg-neutral-800/40 transition"
            >
              <input
                type="checkbox"
                checked={t.completed}
                onChange={() => void onToggle(t)}
                className="w-4 h-4 accent-neutral-900 dark:accent-neutral-100"
              />
              {editingId === t.id ? (
                <input
                  autoFocus
                  value={editingValue}
                  onChange={(e) => setEditingValue(e.target.value)}
                  onBlur={() => void onSaveEdit(t)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") void onSaveEdit(t);
                    if (e.key === "Escape") setEditingId(null);
                  }}
                  className="flex-1 bg-transparent border-b border-neutral-400 dark:border-neutral-600 outline-none"
                />
              ) : (
                <button
                  onDoubleClick={() => {
                    setEditingId(t.id);
                    setEditingValue(t.title);
                  }}
                  className={`flex-1 text-left ${
                    t.completed
                      ? "line-through text-neutral-400 dark:text-neutral-600"
                      : ""
                  }`}
                  title="Doble clic para editar"
                >
                  {t.title}
                </button>
              )}
              <button
                onClick={() => void onDelete(t.id)}
                className="text-xs text-neutral-400 hover:text-red-500 opacity-0 group-hover:opacity-100 transition"
                aria-label="Borrar"
              >
                Borrar
              </button>
            </li>
          ))}
        </ul>

        <footer className="mt-10 text-center text-xs text-neutral-400 dark:text-neutral-600">
          <code className="font-mono">doble clic</code> para editar un título
        </footer>
      </div>
    </div>
  );
}
