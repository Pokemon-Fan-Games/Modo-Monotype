#####################################################################################
#                          CRÉDITOS/CREDITS: DPertierra                                     #
#####################################################################################

class PokemonGlobalMetadata
  attr_accessor :monotype_type
end
module MonotypeChallenge
  BLOQUEAR_EVOLUCIONES_A_OTROS_TIPOS = false

  # Listado de tipos posibles para el reto monotype
  TYPES = [ PBTypes::BUG, PBTypes::NORMAL, PBTypes::POISON,
            PBTypes::FLYING, PBTypes::WATER, PBTypes::GRASS,
            PBTypes::FIRE
          ]

  # Listado de iniciales para cada reto monotype
  # Pueden ser mas de 3 y se tomarán 3 de este listado aleatoriamente.
  STARTER_OPTIONS = {
    PBTypes::BUG    => [PBSpecies::SEWADDLE, PBSpecies::GRUBBIN, PBSpecies::BLIPBUG],
    PBTypes::NORMAL => [PBSpecies::WHISMUR, PBSpecies::LILLIPUP, PBSpecies::ZIGZAGOON],
    PBTypes::POISON => [PBSpecies::ODDISH, PBSpecies::ZUBAT, PBSpecies::VENIPEDE],
    PBTypes::FLYING => [PBSpecies::STARLY, PBSpecies::PIKIPEK, PBSpecies::ROOKIDEE],
    PBTypes::WATER  => [PBSpecies::POLIWAG, PBSpecies::HORSEA, PBSpecies::TYMPOLE],
    PBTypes::GRASS  => [PBSpecies::SEEDOT, PBSpecies::BUDEW, PBSpecies::SMOLIV],
    PBTypes::FIRE   => [PBSpecies::MAGBY, PBSpecies::LITWICK, PBSpecies::ROLYCOLY]
  }

  def self.enabled?
    type ? true : false
  end

  # Devuelve el tipo para el modo monotype
  def self.type
    $PokemonGlobal.monotype_type || nil
  end

  def self.type_name
    type ? PBTypes.getName(type) : nil
  end

  # Guarda el tipo del monotype
  def self.type=(type_index)
    return if type_index >= self::TYPES.length

    selected_type = self::TYPES[type_index]
    $PokemonGlobal.monotype_type = selected_type
  end

  # Devuelve los tipos posibles para el monotype
  def self.type_options
    options = self::TYPES.map { |type| PBTypes.getName(type) }
    options.push(_INTL('NO'))
    options
  end

  # Devuelve 3 starters para el monotype seleccionado
  def self.choose_starter
    return unless $PokemonGlobal.monotype_type

    starters = self::STARTER_OPTIONS[$PokemonGlobal.monotype_type]
    starters.shuffle!
    commands = []

    (0...3).each do |i|
      starter = starters[i]
      commands.push(PBSpecies.getName(starter))
    end

    chosen = -1
    chosen = Kernel.pbMessage(_INTL('Elige a tu nuevo inicial'), commands, -1) while chosen == -1

    pbAddPokemon(starters[chosen], 5)
    pbRemovePokemonAt(0)
    type_name = PBTypes.getName(type)
    Kernel.pbMessage(_INTL("¡A partir de ahora estás en un <b>Reto Monotype</b> de tipo #{type_name}!"))
  end

  # Valida que el pokemon sea valido para el reto monotype elegido
  # Devuelve mensaje de error si no lo es
  def self.valid_monotype_with_text?(poke)
    selected_type = type
    return true if selected_type.nil? # No está activo el monotype

    if poke.is_a?(Integer)
      species = poke
      dexdata = pbOpenDexData
      pbDexDataOffset(dexdata, species, 8) # Type
      type1 = dexdata.fgetb
      type2 = dexdata.fgetb

      evos_types = evolved_types(species)

      unless [type1, type2].include?(selected_type) || evos_types.include?(selected_type)
        return false, PBTypes.getName(selected_type)
      end

    else
      evos_types = evolved_types(poke)

      unless poke.pbHasType?(selected_type) || evos_types.include?(selected_type)
        return false, PBTypes.getName(selected_type)
      end
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
    species = poke.is_a?(Integer) ? poke : poke.species

    evos = pbGetEvolvedFormData(species)
    dexdata = pbOpenDexData
    evos_types = []

    until evos.empty?
      pbDexDataOffset(dexdata, evos.first[2], 8) # Type
      type1 = dexdata.fgetb
      type2 = dexdata.fgetb
      evos_types.push(type1, type2)
      evos = pbGetEvolvedFormData(evos.first[2])
    end

    evos_types
  end
end

# Bloquea la evolucion si no tiene el tipo elegido para el reto monotype
if MonotypeChallenge::BLOQUEAR_EVOLUCIONES_A_OTROS_TIPOS
  alias pbCheckEvolution_mono pbCheckEvolution
  def pbCheckEvolution(pokemon, item = 0)
    new_species = pbCheckEvolution_mono(pokemon, item)
    return -1 if new_species < 0

    return -1 unless MonotypeChallenge.valid_monotype?(new_species)

    new_species
  end
end

module PokeBattle_BattleCommon
  alias pbThrowPokeBall_mono pbThrowPokeBall
  def pbThrowPokeBall(idxPokemon,ball,rareness=nil,showplayer=false,safari=false,firstfailedthrowatsafari=false)
    if MonotypeChallenge.enabled?
      battler = pbIsOpposing?(idxPokemon) ? battlers[idxPokemon] : battlers[idxPokemon].pbOppositeOpposing
      battler = battler.pbPartner if battler.isFainted?

      if MonotypeChallenge.valid_monotype?(battler)
        pbThrowPokeBall_mono(idxPokemon,ball,rareness,showplayer,safari,firstfailedthrowatsafari)
      else
        @scene.pbThrowAndDeflect(ball, 1)
        pbDisplay(_INTL("Solo puedes capturar a Pokémon de tipo #{MonotypeChallenge.type_name}."))
      end
    else
      pbThrowPokeBall_mono(idxPokemon,ball,rareness,showplayer,safari,firstfailedthrowatsafari)
    end
  end
end
