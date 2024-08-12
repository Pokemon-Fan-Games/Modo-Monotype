class PokemonGlobalMetadata
  attr_accessor :monotype_type
end

module MonotypeChallenge

  BLOQUEAR_EVOLUCIONES_A_OTROS_TIPOS = false

  # Listado de tipos posibles para el reto monotype
  TYPES = [:BUG, :NORMAL, :POISON, :FLYING, :WATER, :GRASS, :FIRE]

  # Listado de iniciales para cada reto monotype
  # Pueden ser mas de 3 y se tomarán 3 de este listado aleatoriamente.
  STARTER_OPTIONS = {
    :BUG    => [:SEWADDLE, :GRUBBIN, :BLIPBUG],
    :NORMAL => [:WHISMUR, :LILLIPUP, :ZIGZAGOON],
    :POISON => [:ODDISH, :ZUBAT, :VENIPEDE],
    :FLYING => [:STARLY, :PIKIPEK, :ROOKIDEE],
    :WATER  => [:POLIWAG, :HORSEA, :TYMPOLE],
    :GRASS  => [:SEEDOT, :BUDEW, :SMOLIV],
    :FIRE   => [:MAGBY, :LITWICK, :ROLYCOLY]
  }

  def self.enabled?
    type ? true : false
  end

  # Devuelve el tipo para el modo monotype
  def self.type
    $PokemonGlobal.monotype_type || nil
  end

  # Guarda el tipo del monotype
  def self.type=(type_index)
    return if type_index >= self::TYPES.length

    selected_type = self::TYPES[type_index]
    $PokemonGlobal.monotype_type = selected_type
  end

  # Devuelve los tipos posibles para el monotype
  def self.type_options
    options = self::TYPES.map { |type| GameData::Type.get(type).name }
    options.push('NO')
    options
  end

  def self.no_valid_pokemon_in_party?
    return unless $PokemonGlobal.monotype_type

    pokes_to_remove = []
    $player.party.each_with_index do |poke, index|
      pokes_to_remove.push(index) unless valid_monotype?(poke)
    end

    no_valid = $player.party.length <= pokes_to_remove.length

    pokes_to_remove.each do |poke|
      $player.remove_pokemon_at_index(poke)
    end
    no_valid
  end

  # Devuelve 3 starters para el monotype seleccionado
  def self.choose_starter
    return unless $PokemonGlobal.monotype_type

    starters = self::STARTER_OPTIONS[$PokemonGlobal.monotype_type].sample(3)

    return if starters.empty?

    commands = starters.map { |starter| GameData::Species.get(starter).name }

    chosen = Kernel.pbMessage('Elige a tu nuevo inicial', commands, -1)
    chosen = Kernel.pbMessage('Elige a tu nuevo inicial', commands, -1) while chosen == -1

    pbAddPokemon(starters[chosen], 5)
    $player.remove_pokemon_at_index(0)
    type_name = GameData::Type.get(get_type).name
    Kernel.pbMessage("¡A partir de ahora estás en un <b>Reto Monotype</b> de tipo #{type_name}!")
  end

  # Valida que el pokemon sea valido para el reto monotype elegido
  # Devuelve mensaje de error si no lo es
  def self.valid_monotype_with_text?(poke)
    if poke.is_a?(Symbol)
      species_data = GameData::Species.get(poke)
      return true if species_data.types.include?($PokemonGlobal.monotype_type)

      return false, GameData::Type.get($PokemonGlobal.monotype_type).name
    end
    selected_type = get_type
    return true if selected_type.nil? # No está activo el monotype

    unless poke.hasType?(selected_type) || evolved_types(poke).include?(selected_type)
      return false, GameData::Type.get(selected_type).name
    end

    true
  end

  # Valida que el pokemon sea valido para el monotype elegido
  # Devuelve true si lo es, y false si no
  def self.valid_monotype?(poke)
    is_valid, _text = valid_monotype_with_text?(poke)
    is_valid
  end

  # Valida si alguna de las evoluciones del pokemon tiene el tipo
  # del monotype elegido
  def self.evolved_types(poke)
    return [] unless poke && (poke.is_a?(Pokemon) || poke.is_a?(Symbol))

    species = poke.is_a?(Pokemon) ? poke.species : poke
    form = poke.form || 0
    evos = GameData::Species.get_species_form(species, form).get_evolutions
    evos_types = []

    evos.each do |evo|
      evo_species = evo[0] # Consigue la especie de la evo

      evo_data = GameData::Species.get_species_form(evo_species, form)
      evos_types += evo_data.types
    end

    evos_types.uniq.compact # Remove duplicates and nil values
  end
end

# Bloquea la evolucion si no tiene el tipo elegido para el reto monotype
if MonotypeChallenge::BLOQUEAR_EVOLUCIONES_A_OTROS_TIPOS
  class Pokemon
    alias check_evolution_on_level_up_mono check_evolution_on_level_up
    def check_evolution_on_level_up
      return check_evolution_on_level_up_mono unless MonotypeChallenge.enabled?

      new_species = check_evolution_on_level_up_mono

      new_species = nil if new_species && !MonotypeChallenge.valid_monotype?(new_species)

      new_species
    end

    alias check_evolution_on_use_item_mono check_evolution_on_use_item
    def check_evolution_on_use_item(item_used)
      return check_evolution_on_use_item_mono unless MonotypeChallenge.enabled?

      new_species = check_evolution_on_use_item_mono(item_used)

      new_species = nil if new_species && !MonotypeChallenge.valid_monotype?(new_species)
      new_species
    end

    alias check_evolution_on_trade_mono check_evolution_on_trade
    def check_evolution_on_trade(other_pkmn)
      return check_evolution_on_trade_mono unless MonotypeChallenge.enabled?

      new_species = check_evolution_on_trade_mono(other_pkmn)

      new_species = nil if new_species && !MonotypeChallenge.valid_monotype?(new_species)
      new_species
    end

    alias check_evolution_after_battle_mono check_evolution_after_battle
    def check_evolution_after_battle
      return check_evolution_after_battle_mono unless MonotypeChallenge.enabled?

      new_species = check_evolution_after_battle_mono

      new_species = nil if new_species && !MonotypeChallenge.valid_monotype?(new_species)
      new_species
    end

    alias check_evolution_by_event_mono check_evolution_by_event
    def check_evolution_by_event(value = 0)
      return check_evolution_by_event_mono unless MonotypeChallenge.enabled?

      new_species = check_evolution_by_event_mono(value)

      new_species = nil if new_species && !MonotypeChallenge.valid_monotype?(new_species)
      new_species
    end
  end
end

module Battle::CatchAndStoreMixin
  alias pbThrowPokeBall_mono pbThrowPokeBall
  def pbThrowPokeBall(idxBattler, ball, catch_rate = nil, showPlayer = false)
    battler = opposes?(idxBattler) ? @battlers[idxBattler] : @battlers[idxBattler].pbDirectOpposing(true)
    battler = battler.allAllies[0] if battler.fainted?

    if MonotypeChallenge.enabled? && !MonotypeChallenge.valid_monotype?(battler.pokemon)
      @scene.pbThrowAndDeflect(ball, 1)
      pbDisplay(_INTL("¡Solo puedes capturar pokémon de tipo {1}!", GameData::Type.get(MonotypeChallenge.get_type).name))
    else
      pbThrowPokeBall_mono(idxBattler, ball, catch_rate, showPlayer)
    end
  end
end
