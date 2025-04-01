# frozen_string_literal: true

require "active_record"

module Audited
  # Wrapper around ActiveSupport::CurrentAttributes
  class RequestStore < ActiveSupport::CurrentAttributes
    attribute :audited_store
  end

  class << self
    attr_accessor \
      :auditing_enabled,
      :current_user_method,
      :ignored_attributes,
      :ignored_default_callbacks,
      :max_audits,
      :store_synthesized_enums,
      :namespace_conditions

    attr_writer :audit_class

    def audit_class
      # The audit_class is set as String in the initializer. It can not be constantized during initialization and must
      # be constantized at runtime. See https://github.com/collectiveidea/audited/issues/608
      @audit_class = @audit_class.safe_constantize if @audit_class.is_a?(String)
      @audit_class ||= Audited::Audit
    end

    # remove audit_model in next major version it was only shortly present in 5.1.0
    alias_method :audit_model, :audit_class
    deprecate audit_model: "use Audited.audit_class instead of Audited.audit_model. This method will be removed.",
              deprecator: ActiveSupport::Deprecation.new('6.0.0', 'Audited')

    def store
      RequestStore.audited_store ||= {}
    end

    def config
      yield(self)
    end

    def dev_test_schema
      proc do
        create_table :audits do |t|
          t.column :auditable_id, :string
          t.column :auditable_type, :string
          t.column :associated_id, :string
          t.column :associated_type, :string
          t.column :user_id, :string
          t.column :user_type, :string
          t.column :username, :string
          t.column :action, :string
          t.column :audited_changes, :text
          t.column :json_audited_changes, :text
          t.column :version, :integer, default: 0
          t.column :comment, :string
          t.column :remote_address, :string
          t.column :request_uuid, :string
          t.column :created_at, :datetime
          t.column :service_name, :string
        end
      end
    end
  end

  @ignored_attributes = %w[lock_version created_at updated_at created_on updated_on]
  @ignored_default_callbacks = []
  @namespace_conditions = {}

  @current_user_method = :current_user
  @auditing_enabled = true
  @store_synthesized_enums = false
end

require "audited/auditor"

ActiveSupport.on_load :active_record do
  require "audited/audit"
  include Audited::Auditor
end

require "audited/sweeper"
require "audited/railtie" if Audited.const_defined?(:Rails)
