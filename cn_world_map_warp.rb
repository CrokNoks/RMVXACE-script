#==============================================================================
#    World Map Warp
#    Version: 0.9
#    Author: CrokNoks
#    Date: 17/03/2013
#    Version Date         Author           Comment
#    0.9     17/03/2013   CrokNoks         Beta version for LePalaisDuMaking
#    0.9.1   18/03/2013   CrokNoks         Add : disable the command in the menu
#    0.9.2   27/03/2013   CrokNoks         Add : enable/disable teleportation to a specific location
#
# Licence: Utilisation non-commercial uniquement.
# Me demandez avant de faire des modifications et avant de partager.
# Me citez dans les crédits (avec les deux majuscules :p.)
#
# A venir : Une ligne de description multiligne et ajout d'un menu lors de la validation du lieu.
#    
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

=begin

INSTRUCTIONS 

Le fond de carte utilisé pour l'a vue doit être placé dans Graphics/Pictures 
et doit porter le nom de world_map (voir MAP_NAME pour changer le nom
Ce fond de carte doit AU MINIMUM avoir la taille de la fenètre. Si elle est plus grande, le fond de map se déplacera.

Ajout d'une map au système : 
 - Mettre ces lignes dans la block 'notes' de la map.
<map info warp>
direction 2
entry_point 12 12
map_coord 165 135
known yes
icons 15 12     
<description>
Voici une jolie description.
</description>
</map info warp>
 - Changer les informations : 
 direction : direction dans laquelle sera tourné le perso après l'arrivé sur cette carte. (facultatif, voir DEFAULT_DIRECTION)
 entry_point : coordonnées de la carte actuelle à laquelle, le perso doit être téléporté
 map_coord : coordonnées à laquelle il faut afficher l'icone et/ou le nom du lieu sur la carte du monde.
 known : yes|no|true|false : permet de masquer/afficher un lieu au joueur. (facultatif voir DEFAULT_KNOWN)
 icons : numéros des icones à utilier lorsque le lieu est sélectionné ou non sur la carte du monde. (facultatif, voir CUSTOM_ICONS)
 block description : ajouter une description visible en haut de la map. (facultatif)
 
 Le nom et l'id de la map sont récupérés automatiquement.
 
 L'id de la map se situe en bas à droite de l'éditeur (à coté des coordonnées)
 
 Pour connaitre l'état 'known d'une map : 
  $game_wmw.get(map_id).known
  map_id : id de la map à vérifier
 Pour changer l'état 'known' par event : 
  $game_wmw.known(map_id,bool) 
  map_id : id de la map à modifier.
  bool : true/false
 Pour appeller la vue : 
  SceneManager.call(Scene_WorldMap)
 Pour activer/désactiver la téléportation vers un lieu connu : 
  $game_wmw.teleport(map_id,bool)
=end
module CN_WorldMapWarp
	module Config 
		# Nom du fichier image (must be the Graphics/Pictures folder)
		MAP_NAME = "world_map"
		
		# Pour avoir l'acces par le menu
		IN_MENU = true
    # Nom dans le menu
		ENTRY_NAME = "Carte"
		
    # Si TRUE affiche les noms des lieux sur la carte
		SHOW_LOCATION_NAME = true
    # Si TRUE affiche le nom uniquement si lieu selectionné, ne fonctionne que si SHOW_LOCATION_NAME vaut true
    SHOW_ONLY_SELECTED_LOCATION_NAME = true
    
    # Si -1 utilise la police par défaut
		TEXT_FONT = -1    
    #Si -1 utilise la taille défaut
		TEXT_SIZE = -1
		
    # Numéro du tile de couleur dans le windowskin.
		TEXT_COLOR = 1 # couleur du texte par défaut
		CURRENT_LOC_TEXT_COLOR = 9 # couleur à utiliser sur le lieu séléctionné
		PREVIOUS_LOC_TEXT_COLOR = 4 # couleur à utiliser sur le lieu où l'on a activé la carte
    UNKNOWN_LOC_TEXT_COLOR = 2 # couleur à utiliser pour les lieux inconnu. Ne fonctionne qu'avec DISPLAY_ALL
				
		# Icones par défaut à utiliser si icone non fournis ou si CUSTOM_ICONS = FALSE
		LOCATION_ICONS = [184, 187]

		# si TRUE utilise les icones défini dans la liste de lieu.
    # Sinon Utilise les deux icones présentent ci-dessus.
		CUSTOM_ICONS = true
				
		# Si False, n'affichera pas les lieux inconnus
		DISPLAY_ALL = true
    
    # Si true active la téléportation même pour les lieux non débloqué.
    TELEPORT_FOR_ALL = false
    # Valeur du fondu lors de la téléportation.
    TELEPORT_FADE_TIME = 50
    
		# affichera le texte suivant si DISPLAY_ALL est vrai
		UNKNOWN_TEXT = "??????"
    # affichera le texte suis en description si DISPLAY_ALL est vrai
    UNKNOWN_DESCRIPTION = "??????"
    
    # si TRUE affiche la liste des lieux.
    LIST_OF_LOCATION = true
    
    # Valeur par défaut pour le paramètre known d'un Location
    DEFAULT_KNOWN = true
    
    #valeur par Défaut pour la direction du joueur.
    DEFAULT_DIRECTION = 2 # 2 => bas, 4 => gauche, 6 => droite, 8 => haut
  end
  
  module REGEXP
    module CLASS
      
      MAP_INFO_WARP_ON =
        /<(?:MAP_INFO_WARP|map info warp)>/i
      MAP_INFO_WARP_OFF =
        /<\/(?:MAP_INFO_WARP|map info warp)>/i
      MAP_INFO_DIR_STR = /DIRECTION[ ](\d+)/i
      MAP_INFO_ENTRY_POINT_STR = /ENTRY_POINT[ ](\d+) (\d+)/i
      MAP_INFO_MAP_COORD_STR = /MAP_COORD[ ](\d+) (\d+)/i
      MAP_INFO_MAP_KNOWN_STR = /KNOWN[ ](yes|no|true|false)/i
      MAP_INFO_MAP_ICONS_STR = /icons[ ](\d+) (\d+)/i
      MAP_INFO_MAP_DESC_ON = /<description>/i
      MAP_INFO_MAP_DESC_OFF = /<\/description>/i
      
    end # CLASS
  end # REGEXP
  
end

#==============================================================================
# ** Game_WMW
#------------------------------------------------------------------------------
# This gama object is for manage locations and display the 
# list of location and the map
#==============================================================================
class  Game_WMW

  attr_accessor :maplocations
  attr_accessor :prev_map
  attr_accessor :menu_enabled
  
  def initialize
    @menu_enabled = true
    @maplocations = []
    make_location_list
    sort_location_list    
  end
  
	#--------------------------------------------------------------------------
  # * Generate location list
	#--------------------------------------------------------------------------
  def make_location_list
    $data_mapinfos.each do |map_id,item|
      map = load_data(sprintf("Data/Map%03d.rvdata2", map_id))
      loc = get_notetags(map)
      if !loc.nil?
        loc.map_id = map_id
        loc.name = item.name if loc.name == ''
        @maplocations.push(loc)
      end
    end    
  end
  
	#--------------------------------------------------------------------------
  # * Sort location list to north -> south order
	#--------------------------------------------------------------------------
  def sort_location_list
    @maplocations.sort! { |a, b| a.icon_y <=> b.icon_y}
  end  
  
	#--------------------------------------------------------------------------
  # * Set known value for id
	#--------------------------------------------------------------------------
  def known(map_id,know)
    item = get(map_id)
    item.known = know unless item.nil?
  end 
  
	#--------------------------------------------------------------------------
  # * Set known value for id
	#--------------------------------------------------------------------------
  def teleport(map_id,teleport)
    item = get(map_id)
    item.teleport = teleport unless item.nil?
  end
  
	#--------------------------------------------------------------------------
  # * Get the map's note tag
	#--------------------------------------------------------------------------
  def get_notetags(map)
    map_unlock_on = false
    map_unlock_desc_on = false
    loc = Location.new(0,map.display_name)
    loc.description= ''
    #---
    map.note.split(/[\r\n]+/).each do |line|
      case line
      when CN_WorldMapWarp::REGEXP::CLASS::MAP_INFO_WARP_ON
        map_unlock_on = true
      when CN_WorldMapWarp::REGEXP::CLASS::MAP_INFO_WARP_OFF
        map_unlock_on = false
      when CN_WorldMapWarp::REGEXP::CLASS::MAP_INFO_DIR_STR
        next unless map_unlock_on
        loc.direction = $1.to_i
      when CN_WorldMapWarp::REGEXP::CLASS::MAP_INFO_ENTRY_POINT_STR
        next unless map_unlock_on
        loc.entry_x = $1.to_i
        loc.entry_y = $2.to_i
      when CN_WorldMapWarp::REGEXP::CLASS::MAP_INFO_MAP_COORD_STR
        next unless map_unlock_on
        loc.icon_x = $1.to_i
        loc.icon_y = $2.to_i
      when CN_WorldMapWarp::REGEXP::CLASS::MAP_INFO_MAP_KNOWN_STR
        next unless map_unlock_on
        loc.known = ($1== 'yes')
      when CN_WorldMapWarp::REGEXP::CLASS::MAP_INFO_MAP_ICONS_STR
        next unless map_unlock_on
        loc.selected_icon = $1.to_i
        loc.deselected_icon = $2.to_i
      when CN_WorldMapWarp::REGEXP::CLASS::MAP_INFO_MAP_DESC_ON
        map_unlock_desc_on = true
      when CN_WorldMapWarp::REGEXP::CLASS::MAP_INFO_MAP_DESC_OFF
        map_unlock_desc_on = false
      else
        loc.description += ' '+line if map_unlock_desc_on
      end
    end
    return loc if loc.icon_x >=0 && loc.icon_y >=0
    return nil
  end

	#--------------------------------------------------------------------------
	# * Determine what icon to use for location
	#--------------------------------------------------------------------------
	def determine_location_icon(loc_id,selected_loc_id)
    location_icon = CN_WorldMapWarp::Config::LOCATION_ICONS
    b_custom_icons = CN_WorldMapWarp::Config::CUSTOM_ICONS
    b_selected_map = loc_id == selected_loc_id
    location = get(loc_id)
    if b_custom_icons
      location_icon = [
        (location.deselected_icon == nil) ? location_icon[0] : location.deselected_icon,
				(location.selected_icon == nil) ? location_icon[1] : location.selected_icon
      ]
    end
    
    icon_code = (b_selected_map)? location_icon[1] : location_icon[0]
    enabled = b_selected_map
    
		return {:icon => icon_code, :enabled => enabled}
	end
  
	#--------------------------------------------------------------------------
  # * Get a location by map_id
	#--------------------------------------------------------------------------
  def get(map_id)
    @maplocations.each do |item|
      return item if item.map_id == map_id
    end
    return nil
  end
  
	#--------------------------------------------------------------------------
  # * Get a location by map_id
	#--------------------------------------------------------------------------
  def get_index(map_id)
    @maplocations.each do |index,item|
      return index if item.map_id == map_id
    end
    return nil
  end
  
	#--------------------------------------------------------------------------
  # * Determine what color to use for name
	#--------------------------------------------------------------------------
  def determine_location_color(loc_id,selected_loc_id)
    color = CN_WorldMapWarp::Config::TEXT_COLOR
    b_selected_map = loc_id == selected_loc_id
    location = get(loc_id)
    return  {:color => text_color(0), :enabled => false} if location.nil?
    color = CN_WorldMapWarp::Config::PREVIOUS_LOC_TEXT_COLOR if location.map_id == @prev_map
    color = CN_WorldMapWarp::Config::CURRENT_LOC_TEXT_COLOR if b_selected_map
    
    enabled = location.known && location.teleport
    enabled = false if color == CN_WorldMapWarp::Config::PREVIOUS_LOC_TEXT_COLOR
    
		return {:color => text_color(color), :enabled => enabled}
  end
  
	#--------------------------------------------------------------------------
  # * Convert  color sprite number into color value
	#--------------------------------------------------------------------------
  def text_color(n)
    return Window_Base.new(0,0,0,0).text_color(n)
  end
end

#==============================================================================
# ** Window_Map
#------------------------------------------------------------------------------
#  This window is for selecting a context to display the 
# list of location and the map
#==============================================================================
class Window_Map < Window_Command
	#--------------------------------------------------------------------------
	# * Object Initialization
	#--------------------------------------------------------------------------
	def initialize(pY)
		super(0, pY)
		$game_wmw.prev_map = $game_map.map_id
		@called_from = 0
		@map = Window_Base.new(50, 50, 50, 50)
		@map_image = Cache.picture(CN_WorldMapWarp::Config::MAP_NAME)

		make_location_list
  end
  
  
	#--------------------------------------------------------------------------
	# * Get Window Width
	#--------------------------------------------------------------------------
  def initialize_map()
    x = 0
    y = 0
    x = @location_window.width if CN_WorldMapWarp::Config::LIST_OF_LOCATION && !@location_window.nil?
    y = @location_window.help_window.height if !@location_window.help_window.nil?
    width = Graphics.width
    height = Graphics.height
    
    @map.dispose
    # map is positioned at (-32, -32) as the bitmap is offset by a border
    # of 32 pixels, and this is needed to the image to start at (0, 0)
    @map = Window_Base.new(-32,-32,@map_image.width + 64, @map_image.height + 64)
    @map.z = -10
    @map.contents.dispose
    @map.contents = Bitmap.new(@map.width-32, @map.height-32)
    @map.contents.blt(0, 0, @map_image, Rect.new(0, 0, @map_image.width, @map_image.height))
    
    
    @map.viewport = Viewport.new(x, y, width, height)
	end
  
	#--------------------------------------------------------------------------
	# * Get Window Width
	#--------------------------------------------------------------------------
	def window_width
		return 200
	end
  
	#--------------------------------------------------------------------------
	# * Get Digit Count
	#--------------------------------------------------------------------------
	def col_max
		return 1
	end

	#--------------------------------------------------------------------------
	# * Create Command List
	#--------------------------------------------------------------------------
	def make_command_list
	end
  
	#--------------------------------------------------------------------------
  # * Move player if the selected map is the current map
	#--------------------------------------------------------------------------
  def move_player
    # if the selected location is map the player is on
    Sound.play_cancel

    # find the opposite direction
    opp_direction = case $game_player.direction
    when 2
      8 # down -> up
    when 4
      6 # left -> right
    when 6
      4 # right -> left
    when 8
      2 # up -> down
    end

    # turn the player round and exit
    player_transition($game_wmw.prev_map,
    $game_player.x,
    $game_player.y,
    opp_direction)
  end
  
	#--------------------------------------------------------------------------
  # * teleport player
	#--------------------------------------------------------------------------
  def teleport_player
    return false if @selected_location.known==false && CN_WorldMapWarp::Config::TELEPORT_FOR_ALL==false
    return false if @selected_location.teleport == false
    if @selected_location.map_id == $game_wmw.prev_map
      move_player
    else
      # put the player in the new map
      player_transition(@selected_location.map_id,
      @selected_location.entry_x,
      @selected_location.entry_y,
      @selected_location.direction)
    end
    return true
  end
  
  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
	def update
		super
		# move map according to velocities
		refresh_window_position
	end
	
	#--------------------------------------------------------------------------
	# * Display icone on the map
	#--------------------------------------------------------------------------
	def draw_map_icon(x, y, location)
		icon = $game_wmw.determine_location_icon(location.map_id, @selected_location.map_id)
		@map.draw_icon(icon[:icon], x, y, icon[:enabled])
  end
  
  #--------------------------------------------------------------------------#
  # * Display text on the map
  #--------------------------------------------------------------------------#
  def draw_map_text(x,y,location)
    b_is_selected = location.map_id == @selected_location.map_id
    return unless CN_WorldMapWarp::Config::SHOW_LOCATION_NAME
    return if (CN_WorldMapWarp::Config::SHOW_ONLY_SELECTED_LOCATION_NAME == true && b_is_selected==false )
		text = location.name	 
    text = CN_WorldMapWarp::Config::UNKNOWN_TEXT unless location.known
		# set new font properties only if the value isn't -1
		# in which case defaults will be used
		@map.contents.font.size = CN_WorldMapWarp::Config::TEXT_SIZE unless CN_WorldMapWarp::Config::TEXT_SIZE == -1
		@map.contents.font.name = CN_WorldMapWarp::Config::TEXT_FONT unless CN_WorldMapWarp::Config::TEXT_FONT == -1

		# width and height set AFTER the above to get correct metrics
		height = @map.contents.text_size(text).height+5
		width = @map.contents.text_size(text).width

		color = $game_wmw.determine_location_color(location.map_id, @selected_location.map_id)
    
    @map.change_color(color[:color], color[:enabled])
		@map.draw_text(x+25, y, width, height, text)
	end

	#--------------------------------------------------------------------------
  # * Load the selected map and move the player to the right place
	#--------------------------------------------------------------------------
  def player_transition(map_id, x, y, dir)
		# slightly custom transition script
		$game_map.setup(map_id)
		$game_player.moveto(x, y)
		$game_player.set_direction(dir)
	end
  
  #--------------------------------------------------------------------------
  # * Set Item Window
  #--------------------------------------------------------------------------
  def location_window=(location_window)
    @location_window = location_window
    @location_window.activate
    @location_window.select_last
	
    initialize_map
    update
  end
  
	#--------------------------------------------------------------------------
  # * Generate the lsit of location to display
	#--------------------------------------------------------------------------
  def make_location_list
    @known_locations = []
    $game_wmw.maplocations.each do |loc|
      @known_locations.push(loc) if (loc.known || CN_WorldMapWarp::Config::DISPLAY_ALL)
    end
  end
  
	#--------------------------------------------------------------------------
  # * Display map and location
	#--------------------------------------------------------------------------
  def refresh_window_position
    return if @known_locations.size == 0
    
    @selected_location = @known_locations[@location_window.index]
    # jump straight to the target position
    @target_x = [[@selected_location.icon_x, 172].max, @map_image.width-172-16].min
    @target_y = [[@selected_location.icon_y, 208].max, @map_image.height-208-16].min

    @map.x = 172 - 32 - @target_x
    @map.y = 208 - 32 - @target_y

    @map.contents.clear
    @map.contents.blt(0, 0, @map_image, Rect.new(0, 0, @map_image.width, @map_image.height), 255)

    @known_locations.each do |location|
      draw_map_icon(location.icon_x, location.icon_y, location)
      draw_map_text(location.icon_x, location.icon_y, location)
    end
  end
 
end

#==============================================================================
# ** Window_MapLocations
#------------------------------------------------------------------------------
#  This window is for selecting a category of normal items and equipment
# on the item screen or shop screen.
#==============================================================================
class Window_MapLocations < Window_Selectable
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize(x, y,width,height)
    if !CN_WorldMapWarp::Config::LIST_OF_LOCATION
      x = 0
      y = 0
      width = 0
      height = 0
    end
    
    super
    
    @data = []
    @save_index = 0
    make_item_list
    determine_index
    refresh
  end
  
	#--------------------------------------------------------------------------
  # * Get the index of the current location
	#--------------------------------------------------------------------------
  def determine_index
    map_id = $game_map.map_id
    @save_index = 0
    for i in 0..@data.size-1
        @save_index = i if @data[i].map_id==map_id
    end
    
  end  
  
  #--------------------------------------------------------------------------
  # * Get Digit Count
  #--------------------------------------------------------------------------
  def col_max
    return 1
  end
  
  def width
    return 200
  end
  #--------------------------------------------------------------------------
  # * Get Number of Items
  #--------------------------------------------------------------------------
  def item_max
    @data ? @data.size : 0
  end
  #--------------------------------------------------------------------------
  # * Get Item
  #--------------------------------------------------------------------------
  def item
    @data && index >= 0 ? @data[index] : nil
  end
  
  #--------------------------------------------------------------------------
  # * Get Activation State of Selection Item
  #--------------------------------------------------------------------------
  def current_item_enabled?
    if @data[index]
      if @data[index].known==false && CN_WorldMapWarp::Config::TELEPORT_FOR_ALL==false
        return false
      elsif !@data[index].teleport
        return false
      else
        return true
      end
    end
  end

  #--------------------------------------------------------------------------
  # * Create Item List
  #--------------------------------------------------------------------------
  def make_item_list
    @data.clear
    tabItem = $game_wmw.maplocations
    tabItem.each do |item|
      if item
        if item.known || CN_WorldMapWarp::Config::DISPLAY_ALL
          @data.push(item.clone)
        end
      end
    end
  end
  
  #--------------------------------------------------------------------------
  # * Restore Previous Selection Position
  #--------------------------------------------------------------------------
  def select_last
    select((@data.size == 0 ? nil : (@data.size > @save_index) ? @save_index : @data.size - 1))
  end
  
  #--------------------------------------------------------------------------
  # * Draw Item
  #--------------------------------------------------------------------------
  def draw_item(index)
    location = @data[index]
    return unless location
    return if CN_WorldMapWarp::Config::DISPLAY_ALL==false && location.known==false    
    rect = item_rect(index)
    rect.width -= 4
    draw_item_icon(location, rect.x, rect.y)
    draw_item_name(location, rect.x, rect.y)
    
  end
  
  #--------------------------------------------------------------------------
  # * Draw Item Icon
  #--------------------------------------------------------------------------
  def draw_item_icon(item, x, y)
    icon = item.selected_icon    
    icon = CN_WorldMapWarp::Config::LOCATION_ICONS[1] if icon.nil? || !CN_WorldMapWarp::Config::CUSTOM_ICONS
    return if icon.nil?
    draw_icon(icon, x, y, true)
  end
  
  #--------------------------------------------------------------------------
  # * Draw Item Name
  #--------------------------------------------------------------------------
  def draw_item_name(item, x, y, width = 172)    
		text = item.name	 
    text = CN_WorldMapWarp::Config::UNKNOWN_TEXT unless item.known
    color = $game_wmw.determine_location_color(item.map_id,@data[@index].map_id)
    change_color(normal_color, true)

    draw_text(x + 24, y, width, line_height, text)
  end

  #--------------------------------------------------------------------------
  # * Refresh
  #--------------------------------------------------------------------------
  def refresh
    create_contents
    draw_all_items
  end
  
  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
  def update
    super
  end
  
  #--------------------------------------------------------------------------
  # * Update Help Text
  #--------------------------------------------------------------------------
  def update_help 
    item = @data[index]
    if item
      item.description = CN_WorldMapWarp::Config::UNKNOWN_DESCRIPTION unless item.known
      item.description = item.description_real if item.known
      @help_window.set_item(item)
    end
  end
end

#==============================================================================
# ** Scene_WorldMap
#------------------------------------------------------------------------------
#  This Scene performs Wolrd Map Warping 
#==============================================================================
class Scene_WorldMap < Scene_MenuBase
  #--------------------------------------------------------------------------
  # * Start Processing
  #--------------------------------------------------------------------------
  def start
    super
    create_help_window
    create_location_window
    create_context_window
  end
  
  #--------------------------------------------------------------------------
  # * Create Context Window
  #--------------------------------------------------------------------------
  def create_context_window
    wy = 0
    wh = Graphics.height - wy
    @mapwarp_window = Window_Map.new(wh)
    @mapwarp_window.viewport = @viewport
    @mapwarp_window.set_handler(:cancel, method(:return_scene))
    
    @mapwarp_window.location_window = @location_window
    @mapwarp_window.help_window = @help_window
  end

  #--------------------------------------------------------------------------
  # * Create Locations Window
  #--------------------------------------------------------------------------
  def create_location_window
    wy = @help_window.height
    wh = Graphics.height - wy
    @location_window = Window_MapLocations.new(0, wy,200,wh)
    @location_window.viewport = @viewport
    @location_window.set_handler(:ok,    method(:on_location_ok))
    @location_window.help_window = @help_window
  end

  #--------------------------------------------------------------------------
  # * What to do when the player have choose a location
  #--------------------------------------------------------------------------
  def on_location_ok
    Graphics.fadeout(CN_WorldMapWarp::Config::TELEPORT_FADE_TIME)    
    @mapwarp_window.call_handler(:cancel) if SceneManager.scene_is?(Scene_WorldMap)
    SceneManager.scene().return_scene if SceneManager.scene_is?(Scene_Menu)
    return unless @mapwarp_window.teleport_player
    $scene = Scene_Map.new
  end
end
#==============================================================================
# ** Window_MenuCommand
#------------------------------------------------------------------------------
#  This command window appears on the menu screen.
#==============================================================================
class Window_MenuCommand < Window_Command
    
  #--------------------------------------------------------------------------
  # * add_main_commands
  #--------------------------------------------------------------------------
  alias cnwp_add_main_commands add_main_commands
  def add_main_commands
    cnwp_add_main_commands
    add_command(CN_WorldMapWarp::Config::ENTRY_NAME, :worldmap, $game_wmw.menu_enabled) if CN_WorldMapWarp::Config::IN_MENU
  end
end

#==============================================================================
# ** Scene_Menu
#------------------------------------------------------------------------------
#  This class performs the menu screen processing.
#==============================================================================
class Scene_Menu < Scene_MenuBase

  #--------------------------------------------------------------------------
  # * create_command_window
  #--------------------------------------------------------------------------
  alias cnwp_create_command_window create_command_window
  def create_command_window
    cnwp_create_command_window
    @command_window.set_handler(:worldmap, method(:command_worldmap)) if CN_WorldMapWarp::Config::IN_MENU
  end
  
  #--------------------------------------------------------------------------
  # * command_alchimie
  #--------------------------------------------------------------------------
  def command_worldmap
    SceneManager.call(Scene_WorldMap)
  end
end

class Location
	def initialize(map_id=0,
		name='',
		direction=0,
		entry_coords=[nil,nil],
		icon_coords=[-1,-1],
		location_known=nil,
    teleport=true,
		custom_icons = [nil, nil])

	@name = name
	@direction = direction
	@entry_x = entry_coords[0]
	@entry_y = entry_coords[1]
	@map_id = map_id
	@icon_x = icon_coords[0]
	@icon_y = icon_coords[1]
	@known = location_known
	@icon_index = @deselected_icon
	@deselected_icon = custom_icons[0]
	@selected_icon = custom_icons[1]
  @teleport = teleport
  
  @known = CN_WorldMapWarp::Config::DEFAULT_KNOWN if @known.nil?
  @direction = CN_WorldMapWarp::Config::DEFAULT_DIRECTION if @direction==0
  end

  # all can be modified
  attr_accessor :name
  attr_accessor :direction
  attr_accessor :entry_x
  attr_accessor :entry_y
  attr_accessor :map_id
  attr_accessor :icon_x
  attr_accessor :icon_y
  attr_accessor :known
  attr_accessor :selected_icon
  attr_accessor :deselected_icon
  attr_accessor :icon_index
  attr_accessor :description
  attr_accessor :description_real
  attr_accessor :teleport
  
  def description=(text)
      @description_real = @description = text      
  end
  

end

#==============================================================================
# *** DataManager
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#  Summary of Changes:
#    aliased method - self.extract_save_contents
#==============================================================================

module DataManager
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # * Extract Save Contents
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  class <<self; alias cn_extractsavecons_wmw extract_save_contents;  end
  def self.extract_save_contents(contents)
    cn_extractsavecons_wmw(contents)
    $game_wmw = contents[:wmw]
  end 
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # * Save WMW Contents
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  class <<self; alias cn_make_save_contents_wmw make_save_contents; end
  def self.make_save_contents
    contents = cn_make_save_contents_wmw
    contents[:wmw] = $game_wmw
    contents
  end  
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # * Initialize WMW Contents
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  class <<self; alias cn_create_game_objects_wmw create_game_objects; end
  def self.create_game_objects
    cn_create_game_objects_wmw
    $game_wmw = Game_WMW.new
  end  
end
