module Deltacloud

  def self.test_environment?
    ENV['RACK_ENV'] == 'test' || ENV['DELTACLOUD_NO_DATABASE']
  end

  require 'sequel' unless test_environment?
  require 'logger'

  DATABASE_LOCATION = ENV['DATABASE_LOCATION'] ||
    'sqlite://'+File.join('/', 'var', 'tmp', "deltacloud-mock-#{ENV['USER']}", 'db.sqlite')

  def self.database(opts={})
    opts[:logger] = ::Logger.new($stdout) if ENV['API_VERBOSE']
    @db ||=  Sequel.connect(DATABASE_LOCATION, opts)
  end

  def self.initialize_database

    database.create_table?(:providers) {
      primary_key :id

      column :driver, :string, { :null => false }
      column :url, :string
      index [ :url, :driver ]
    }

    database.create_table?(:entities) {
      primary_key :id
      foreign_key :provider_id, :providers, { :index => true, :null => false }
      column :created_at, :timestamp

      # Base
      column :model, :string, { :index => true, :null => false, :default => 'entity' }

      # Map Entity to Deltacloud model
      # (like: Machine => Instance)
      column :be_kind, :string
      column :be_id, :string

      # Entity
      column :name, :string
      column :description, :string
      column :ent_properties, :string, { :text => true }


      column :machine_config, :string
      column :machine_image, :string

      column :network, :string
      column :ip, :string
      column :hostname, :string
      column :allocation, :string
      column :default_gateway, :string
      column :dns, :string
      column :protocol, :string
      column :mask, :string

      column :format, :string
      column :capacity, :string

      column :volume_config, :string
      column :volume_image, :string
    }
  end

end

unless Deltacloud.test_environment?
  Deltacloud::initialize_database
  require_relative './db/provider'
  require_relative './db/entity'
  require_relative './db/machine_template'
  require_relative './db/address_template'
  require_relative './db/volume_configuration'
  require_relative './db/volume_template'
end
