module HomeHelper
  # Heroicons solid play and pause marks.
  MEDIA_ICONS = {
    play: "M4.5 5.653c0-1.427 1.529-2.33 2.779-1.643l11.54 6.347c1.295.712 1.295 2.573 0 3.286L7.28 19.99c-1.25.687-2.779-.217-2.779-1.643V5.653Z",
    pause: "M6.75 5.25a.75.75 0 0 1 .75-.75H9a.75.75 0 0 1 .75.75v13.5a.75.75 0 0 1-.75.75H7.5a.75.75 0 0 1-.75-.75V5.25Zm7.5 0a.75.75 0 0 1 .75-.75H16.5a.75.75 0 0 1 .75.75v13.5a.75.75 0 0 1-.75.75h-1.5a.75.75 0 0 1-.75-.75V5.25Z"
  }.freeze

  def player_state_badge_class(state)
    base = "rounded-full px-3 py-1 text-sm"
    case state
    when "playing" then "#{base} bg-emerald-900/80 text-emerald-300"
    when "paused" then "#{base} bg-amber-900/80 text-amber-300"
    else "#{base} bg-zinc-800 text-zinc-400"
    end
  end

  def player_title(now_playing)
    now_playing[:title].presence || (now_playing[:state] == "stopped" ? "Nothing playing" : "Starting…")
  end

  def media_icon(name)
    tag.svg(
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 24 24",
      fill: "currentColor",
      class: "size-5 shrink-0",
      aria: { hidden: true }
    ) do
      tag.path("fill-rule": "evenodd", "clip-rule": "evenodd", d: MEDIA_ICONS.fetch(name))
    end
  end

  def transport_play_class
    "inline-flex items-center gap-2 rounded-lg bg-violet-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-violet-500 disabled:pointer-events-none disabled:opacity-40"
  end

  def transport_pause_class
    "inline-flex items-center gap-2 rounded-lg border border-zinc-600 bg-zinc-800 px-5 py-2.5 text-sm font-semibold text-zinc-100 hover:bg-zinc-700 disabled:pointer-events-none disabled:opacity-40"
  end

  def library_play_class
    "rounded-md bg-violet-600 px-3 py-1 text-xs font-semibold text-white hover:bg-violet-500"
  end

  def library_tab_class(active)
    base = "border-b-2 px-3 py-2 text-sm font-medium"
    if active
      "#{base} border-violet-400 text-zinc-50"
    else
      "#{base} border-transparent text-zinc-400 hover:text-zinc-200"
    end
  end

  def library_section_class(active)
    base = "rounded-md px-3 py-1 text-sm font-medium"
    if active
      "#{base} bg-violet-600 text-white"
    else
      "#{base} bg-zinc-800 text-zinc-300 hover:bg-zinc-700"
    end
  end

  def control_qr_svg(url)
    svg = ::RQRCode::QRCode.new(url).as_svg(
      color: "e4e4e7",
      fill: "09090b",
      shape_rendering: "crispEdges",
      module_size: 5,
      offset: 12,
      standalone: true,
      use_path: true,
      viewbox: true
    )
    svg = svg.sub(/\A<\?xml[^>]*\?>/, "")
    svg = svg.sub(
      "<svg ",
      '<svg class="block h-full w-full" '
    )
    svg.html_safe
  end
end
