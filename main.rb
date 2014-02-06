require 'csv'
require 'json'
require 'logger'

require 'citysdk'
require 'trollop'

def parse_options
  opts = Trollop::options do
    opt(:config,
        'Configuration JSON file',
        :type => :string)
    opt(:username,
        'CitySDK username',
        :type => :string)
    opt(:host_url,
        'CitySDK endpoint URL',
        :type => :string)
    opt(:password,
        'CitySDK password',
        :type => :string)
    opt(:naptan_csv,
        'NaPTAN Rail Reference CSV',
        :type => :string)
    opt(:layer_name,
        'Name of layer to import Network Rail data to',
        :type => :string)
    opt(:layer_description,
        'Description of layer to import Network Rail data to',
        :type => :string)
    opt(:layer_organization,
        'Organization of layer to import Network Rail data to',
        :type => :string)
    opt(:layer_category,
        'Category of layer to import Network Rail data to',
        :type => :string)
    opt(:layer_webservice,
        'Webservice of layer to import Network Rail data to',
        :type => :string)
  end # do

  if opts[:config]
    config_file = opts[:config]
    config = JSON.parse(IO.read(config_file), {symbolize_names: true})
    opts = opts.merge(config)
  end # if

  [:username,
   :password,
   :host_url,
   :naptan_csv,
   :layer_name,
   :layer_description,
   :layer_organization,
   :layer_category,
   :layer_webservice].each do |option|
    unless opts[option]
      Trollop::die option, 'must be specified.'
    end # do
  end # each

  opts
end # def

def get_naptan_rail_references(naptan_csv)
  CSV.read(naptan_csv, {headers: true})
end # def

def get_citysdk_railway_stations(api)
  railway_station_node_iterator = CitySDK::NodesPaginator.new(api,
    'layer' => 'osm',
    'osm::railway' => 'station',
    'per_page' => '100'
  )

  stations = []
  while railway_station_node_iterator.has_next()
    api_results = railway_station_node_iterator.next()
    stations.concat api_results.fetch('results')
  end # while

  return stations
end # def

def match_by_atco_code?(station, rail_reference)
  # Some stations have AtcoCodes added to their OSM data.
  station_has_naptan = station['layers']['osm']['data'].has_key?('naptan')
  return false unless station_has_naptan
  station_atco_code = station['layers']['osm']['data']['naptan']['AtcoCode']
  station_atco_code == rail_reference.fetch('AtcoCode')
end

def match_by_tiploc?(station, rail_reference)
  # Rarely they have tiplocs added to their OSM data - this is the very code
  # we need for linking with the Network Rail SCHEDULE data.
  station_osm_data = station.fetch('layers').fetch('osm').fetch('data')
  station_has_ref = station_osm_data.key?('ref')
  return false unless station_has_ref
  station_ref = station_osm_data.fetch('ref')
  return unless station_ref.is_a?(Hash)
  station_has_tiploc = station_ref.key?('tiploc')
  return false unless station_has_tiploc
  station_tiploc = station_ref.fetch('tiploc')
  station_tiploc == rail_reference.fetch('TiplocCode')
end

def match_by_name?(station, rail_reference)
  # Fuzzy guess the name, all NaPTAN stations seem to have "Rail Station" at
  # the end of their names, so try matching it against it raw and with
  # "Rail Station stripped off.
  name = station.fetch('name')
  rail_reference = rail_reference.fetch('StationName')
  rail_reference_clean = rail_reference.split('Rail Station').first.strip()
  name == rail_reference_clean or name == rail_reference
end

def match?(station, rail_reference)
  match_by_atco_code?(station, rail_reference) \
    or match_by_tiploc?(station, rail_reference) \
    or match_by_name?(station, rail_reference)
end # def

def create_layer(name, description, organization, category, webservice)

end # def


def main
  opts = parse_options()

  logger = Logger.new(STDOUT)

  api = CitySDK::API.new(opts.fetch(:host_url))
  api.set_credentials(opts.fetch(:username), opts.fetch(:password))
  layer_name = opts.fetch(:layer_name)
  unless api.layer?(layer_name)
    logger.info("layer #{layer_name} does not exist, creating it")
    api.create_layer(
      name: layer_name,
      organization: opts.fetch(:layer_organization),
      category: opts.fetch(:layer_category),
      description: opts.fetch(:layer_description),
      webservice: opts.fetch(:layer_webservice)
    )
  end #unless

  logger.info('Reading naptan rail references')
  rail_references = get_naptan_rail_references(opts.fetch(:naptan_csv))

  logger.info('Getting stations from CitySDK API')
  stations = get_citysdk_railway_stations(api)

  logger.info('Matching csdk nodes to naptan rail references')
  matches = 0
  cdk_nodes = []
  stations.each do |station|
    match = false
    rail_references.each do |rail_reference|
      if match?(station, rail_reference)
        cdk_nodes.push({
          'cdk_id' => station.fetch('cdk_id'),
          'modalities' => ['rail'],
          'data' => {
            'tiploc_code' => rail_reference.fetch('TiplocCode')
          }
        })
        match = true
        matches += 1
      end # if
    end # do
    unless match
      logger.warn("No match for station #{JSON.pretty_generate(station)}")
    end # unless
  end # do
  logger.info("#{matches}/#{stations.length} stations matched")

  logger.info('Uploading nodes')
  api.create_nodes(layer_name, cdk_nodes)
  logger.info('Done :-)')
end # def

if __FILE__ == $0
  main()
end # if

