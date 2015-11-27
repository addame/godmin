require "godmin/helpers/batch_actions"
require "godmin/helpers/filters"
require "godmin/helpers/tables"

module Godmin
  module Resources
    module ResourceController
      extend ActiveSupport::Concern

      included do
        helper Godmin::Helpers::BatchActions
        helper Godmin::Helpers::Filters
        helper Godmin::Helpers::Tables

        before_action :set_resource_service
        before_action :set_resource_class
        before_action :set_resources, only: :index
        before_action :set_resource, only: [:show, :new, :edit, :create, :update, :destroy]
      end

      def index
        respond_to do |format|
          format.html
          format.json
          format.csv
        end
      end

      def show
        respond_to do |format|
          format.html
          format.json
        end
      end

      def new; end

      def edit; end

      def create
        respond_to do |format|
          if @resource_service.create_resource(@resource)
            format.html { redirect_to redirect_after_create, notice: redirect_flash_message }
            format.json { render :show, status: :created, location: @resource }
          else
            format.html { render :edit }
            format.json { render json: @resource.errors, status: :unprocessable_entity }
          end
        end
      end

      def update
        respond_to do |format|
          if @resource_service.update_resource(@resource, resource_params)
            format.html { redirect_to redirect_after_update, notice: redirect_flash_message }
            format.json { render :show, status: :ok, location: @resource }
          else
            format.html { render :edit }
            format.json { render json: @resource.errors, status: :unprocessable_entity }
          end
        end
      end

      def destroy
        @resource_service.destroy_resource(@resource)

        respond_to do |format|
          format.html { redirect_to redirect_after_destroy, notice: redirect_flash_message }
          format.json { head :no_content }
        end
      end

      protected

      def set_resource_service
        @resource_service = resource_service
      end

      def set_resource_class
        @resource_class = resource_class
      end

      def set_resources
        @resources = resources
        authorize(@resources) if authorization_enabled?
      end

      def set_resource
        @resource = resource
        authorize(@resource) if authorization_enabled?
      end

      def resource_service_class
        "#{controller_path.singularize}_service".classify.constantize
      end

      def resource_service
        if authentication_enabled?
          resource_service_class.new(admin_user: admin_user)
        else
          resource_service_class.new
        end
      end

      def resource_class
        @resource_service.resource_class
      end

      def resources
        @resource_service.resources(params)
      end

      def resource
        if params[:id]
          @resource_service.find_resource(params[:id])
        else
          case action_name
          when "create"
            @resource_service.build_resource(resource_params)
          when "new"
            @resource_service.build_resource(nil)
          end
        end
      end

      def resource_params
        params.require(@resource_class.model_name.param_key.to_sym).permit(resource_params_defaults)
      end

      def resource_params_defaults
        @resource_service.attrs_for_form.map do |attribute|
          association = @resource_class.reflect_on_association(attribute)

          if association && association.macro == :belongs_to
            association.foreign_key.to_sym
          else
            attribute
          end
        end
      end

      def redirect_after_create
        redirect_after_save
      end

      def redirect_after_update
        redirect_after_save
      end

      def redirect_after_save
        @resource
      end

      def redirect_after_destroy
        resource_class.model_name.route_key.to_sym
      end

      def redirect_flash_message
        translate_scoped("flash.#{action_name}", resource: @resource.class.model_name.human)
      end

      concerning :BatchActions do
        included do
          prepend_before_action :perform_batch_action, only: :update
        end

        protected

        def perform_batch_action
          return unless params[:batch_action].present?

          set_resource_service
          set_resource_class

          if authorization_enabled?
            authorize(batch_action_records, "batch_action_#{params[:batch_action]}?")
          end

          if @resource_service.batch_action(params[:batch_action], batch_action_records)
            flash[:notice] = translate_scoped(
              "flash.batch_action", number_of_records: batch_action_ids.length,
                                    resource: @resource_class.model_name.human(count: batch_action_ids.length)
            )
            flash[:updated_ids] = batch_action_ids

            if respond_to?("redirect_after_batch_action_#{params[:batch_action]}", true)
              redirect_to send("redirect_after_batch_action_#{params[:batch_action]}") and return
            end
          end

          redirect_to :back
        end

        def batch_action_ids
          @_batch_action_ids ||= params[:id].split(",").map(&:to_i)
        end

        def batch_action_records
          @_batch_action_records ||= @resource_class.where(id: batch_action_ids)
        end
      end
    end
  end
end
