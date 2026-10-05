export type Task = {
  id: string;
  title: string;
  completed: boolean;
  createdAt: string;
  updatedAt: string;
};

const BASE = import.meta.env.VITE_API_URL?.replace(/\/$/, "") ?? "";

if (!BASE) {
  console.warn("VITE_API_URL is not set — API calls will fail");
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...init,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `${res.status} ${res.statusText}`);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

export const api = {
  list: () => request<Task[]>("/tasks"),
  create: (title: string) =>
    request<Task>("/tasks", {
      method: "POST",
      body: JSON.stringify({ title }),
    }),
  update: (id: string, patch: Partial<Pick<Task, "title" | "completed">>) =>
    request<Task>(`/tasks/${id}`, {
      method: "PUT",
      body: JSON.stringify(patch),
    }),
  remove: (id: string) =>
    request<void>(`/tasks/${id}`, { method: "DELETE" }),
};
