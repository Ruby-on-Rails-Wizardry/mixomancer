module ApplicationHelper
  def nav_link(label, path)
    active = if path == library_path
      action_name == "library"
    elsif path == root_path
      action_name == "index"
    else
      current_page?(path)
    end
    classes = [ "text-sm font-medium", active ? "text-violet-300" : "text-zinc-400 hover:text-zinc-200" ]
    link_to label, path, class: classes.join(" "), "aria-current": (active ? "page" : nil)
  end
end
