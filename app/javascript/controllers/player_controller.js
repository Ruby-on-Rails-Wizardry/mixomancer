import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["badge", "title", "album", "position", "duration", "index", "progress", "play", "pause", "meta", "track", "bar", "backdrop"]
  static values = { url: String, seekUrl: String, replayUrl: String, forwardUrl: String, interval: { type: Number, default: 2000 } }

  connect() {
    this.dragging = false
    this.durationSeconds = 0
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
    this.refresh()
  }

  disconnect() {
    clearInterval(this.timer)
  }

  startSeek(event) {
    if (!this.canSeek()) return
    this.dragging = true
    event.currentTarget.setPointerCapture(event.pointerId)
    this.scrub(event, { commit: true })
  }

  moveSeek(event) {
    if (!this.dragging) return
    this.scrub(event, { commit: false })
    this.throttledCommit(event)
  }

  endSeek(event) {
    if (!this.dragging) return
    this.dragging = false
    this.scrub(event, { commit: true })
  }

  replay(event) {
    event.preventDefault()
    this.commitRelativeSeek(this.replayUrlValue, 30)
  }

  forward(event) {
    event.preventDefault()
    this.commitRelativeSeek(this.forwardUrlValue, 30)
  }

  async refresh() {
    if (this.dragging) return
    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "application/json" },
        cache: "no-store"
      })
      if (!response.ok) return
      this.apply(await response.json())
    } catch (_error) {
      // Keep the last rendered state if a poll fails.
    }
  }

  apply(data) {
    this.latest = data
    this.durationSeconds = Number(data.duration) || 0
    const state = data.state || "stopped"
    const playing = state === "playing"
    const stopped = state === "stopped"

    if (this.hasBadgeTarget) {
      this.badgeTarget.textContent = state
      this.badgeTarget.className = this.stateClass(state)
      this.badgeTarget.parentElement?.classList.toggle("hidden", playing)
    }
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = data.title || (stopped ? "Nothing playing" : "Starting…")
    }
    if (this.hasAlbumTarget) {
      this.albumTarget.textContent = data.album || ""
    }
    if (this.hasPositionTarget) {
      this.positionTarget.textContent = data.position_label || "0:00"
    }
    if (this.hasDurationTarget) {
      this.durationTarget.textContent = data.duration_label || "0:00"
    }
    if (this.hasIndexTarget) {
      if (data.playlist_pos && data.playlist_count) {
        this.indexTarget.textContent = `${data.playlist_pos} of ${data.playlist_count}`
      } else {
        this.indexTarget.textContent = ""
      }
    }
    if (this.hasProgressTarget && !this.dragging) {
      this.progressTarget.style.width = `${data.percent || 0}%`
    }
    this.metaTargets.forEach((el) => el.classList.toggle("hidden", stopped))
    if (this.hasPlayTarget) {
      this.playTarget.disabled = playing
    }
    if (this.hasPauseTarget) {
      this.pauseTarget.disabled = !playing
    }
    if (this.hasBackdropTarget) {
      const url = data.artwork_url
      if (url) {
        this.backdropTarget.style.backgroundImage = `url('${url}')`
        this.backdropTarget.classList.add("is-on")
      } else {
        this.backdropTarget.style.backgroundImage = ""
        this.backdropTarget.classList.remove("is-on")
      }
    }
    this.trackTargets.forEach((el) => {
      const current = Boolean(data.path) && el.dataset.path === data.path
      el.classList.toggle("text-emerald-300", current)
      el.classList.toggle("text-zinc-300", !current)
    })
  }

  canSeek() {
    const state = this.latest?.state
    return Boolean(this.hasBarTarget && this.durationSeconds > 0 && state && state !== "stopped")
  }

  scrub(event, { commit }) {
    const percent = this.percentFromEvent(event)
    if (this.hasProgressTarget) this.progressTarget.style.width = `${percent}%`
    if (this.hasPositionTarget) this.positionTarget.textContent = this.formatTime(this.durationSeconds * percent / 100)
    if (commit) this.commitSeek(percent)
  }

  throttledCommit(event) {
    const now = Date.now()
    if (this.lastCommitAt && now - this.lastCommitAt < 120) return
    this.commitSeek(this.percentFromEvent(event))
  }

  percentFromEvent(event) {
    const rect = this.barTarget.getBoundingClientRect()
    if (rect.width <= 0) return 0
    const x = Math.min(Math.max(event.clientX - rect.left, 0), rect.width)
    return (x / rect.width) * 100
  }

  async commitRelativeSeek(url, seconds) {
    if (!url) return
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": token
        },
        body: JSON.stringify({ seconds })
      })
      if (!response.ok) return
      this.apply(await response.json())
    } catch (_error) {
      // Next poll will resync.
    }
  }

  async commitSeek(percent) {
    if (!this.hasSeekUrlValue) return
    this.lastCommitAt = Date.now()
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      const response = await fetch(this.seekUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": token
        },
        body: JSON.stringify({ percent })
      })
      if (!response.ok || this.dragging) return
      this.apply(await response.json())
    } catch (_error) {
      // Leave the scrubbed position; the next poll will resync.
    }
  }

  formatTime(seconds) {
    const total = Math.max(0, Math.floor(seconds || 0))
    const hours = Math.floor(total / 3600)
    const minutes = Math.floor((total % 3600) / 60)
    const secs = total % 60
    if (hours > 0) {
      return `${hours}:${String(minutes).padStart(2, "0")}:${String(secs).padStart(2, "0")}`
    }
    return `${minutes}:${String(secs).padStart(2, "0")}`
  }

  stateClass(state) {
    const base = "rounded-full px-3 py-1 text-sm"
    if (state === "playing") return `${base} bg-emerald-900/80 text-emerald-300`
    if (state === "paused") return `${base} bg-amber-900/80 text-amber-300`
    return `${base} bg-zinc-800 text-zinc-400`
  }
}
