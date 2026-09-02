class IrRemote
  CATALOG = Rails.root.join("config/ir_remotes.yml").freeze

  attr_reader :id, :name, :note, :protocol, :address, :bits, :freq, :repeat, :buttons, :layout

  def initialize(id, attrs)
    @id = id.to_s
    @name = attrs.fetch("name")
    @note = attrs["note"]
    @protocol = attrs.fetch("protocol")
    @address = attrs.fetch("address")
    @bits = attrs["bits"]
    @freq = attrs.fetch("freq")
    @repeat = attrs.fetch("repeat", 1)
    @buttons = attrs.fetch("buttons")
    @layout = attrs.fetch("layout")
  end

  def self.all
    catalog.map { |id, attrs| new(id, attrs) }
  end

  def self.find(id)
    attrs = catalog[id.to_s]
    return nil unless attrs

    new(id, attrs)
  end

  def button(name)
    buttons[name.to_s]
  end

  def payload_for(name)
    spec = button(name)
    return nil unless spec

    payload = {
      "protocol" => protocol,
      "address" => address,
      "command" => spec.fetch("command"),
      "freq" => spec["freq"] || freq,
      "repeat" => spec["repeat"] || repeat
    }
    payload["bits"] = spec["bits"] || bits if (spec["bits"] || bits)
    payload
  end

  def rows
    layout.map do |row|
      Array(row).map do |slot|
        next :spacer if slot.nil? || slot == "~" || slot == ""

        key = slot.to_s
        spec = button(key)
        next :spacer unless spec

        { id: key, **spec.symbolize_keys }
      end
    end
  end

  def self.catalog
    @catalog ||= YAML.load_file(CATALOG)
  end
  private_class_method :catalog
end
