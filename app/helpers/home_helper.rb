module HomeHelper
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

  def transport_play_class
    "rounded-lg bg-violet-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-violet-500 disabled:pointer-events-none disabled:opacity-40"
  end

  def transport_stop_class
    "rounded-lg border border-zinc-600 bg-zinc-800 px-5 py-2.5 text-sm font-semibold text-zinc-100 hover:bg-zinc-700 disabled:pointer-events-none disabled:opacity-40"
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
