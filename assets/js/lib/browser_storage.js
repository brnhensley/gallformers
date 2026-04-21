function getStorage() {
  try {
    return window.localStorage
  } catch (_error) {
    return null
  }
}

export function storageGet(key) {
  const storage = getStorage()
  if (!storage) return null

  try {
    return storage.getItem(key)
  } catch (_error) {
    return null
  }
}

export function storageSet(key, value) {
  const storage = getStorage()
  if (!storage) return false

  try {
    storage.setItem(key, value)
    return true
  } catch (_error) {
    return false
  }
}

export function storageRemove(key) {
  const storage = getStorage()
  if (!storage) return false

  try {
    storage.removeItem(key)
    return true
  } catch (_error) {
    return false
  }
}
