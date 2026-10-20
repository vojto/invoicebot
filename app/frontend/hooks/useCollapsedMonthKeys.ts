import { useState } from "react"
import { z } from "zod"

/*
 * Remembers which month groups are collapsed on a list page (transactions,
 * dashboard invoices). Keys persist in localStorage under storageKey, so the page
 * reopens with the same months collapsed. When localStorage is unavailable
 * (private mode, SSR) everything starts expanded and toggling works in memory.
 */

function loadMonthKeys(storageKey: string): string[] {
  if (typeof window === "undefined") return []

  try {
    const value = JSON.parse(window.localStorage.getItem(storageKey) || "[]")
    return z.array(z.string()).catch([]).parse(value)
  } catch {
    return []
  }
}

function saveMonthKeys(storageKey: string, monthKeys: string[]) {
  try {
    window.localStorage.setItem(storageKey, JSON.stringify(monthKeys))
  } catch {
    // Collapsing still works in memory when local storage is unavailable.
  }
}

export default function useCollapsedMonthKeys(storageKey: string) {
  const [collapsedMonthKeys, setCollapsedMonthKeys] = useState<string[]>(() => loadMonthKeys(storageKey))

  function toggleMonth(monthKey: string) {
    const nextMonthKeys = collapsedMonthKeys.includes(monthKey)
      ? collapsedMonthKeys.filter((key) => key !== monthKey)
      : [...collapsedMonthKeys, monthKey]
    setCollapsedMonthKeys(nextMonthKeys)
    saveMonthKeys(storageKey, nextMonthKeys)
  }

  return {
    isMonthCollapsed: (monthKey: string) => collapsedMonthKeys.includes(monthKey),
    toggleMonth,
  }
}
