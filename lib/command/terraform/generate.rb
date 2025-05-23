# frozen_string_literal: true

module Command
  module Terraform
    class Generate < Base
      SUBCOMMAND_NAME = "terraform"
      NAME = "generate"
      OPTIONS = [
        app_option,
        dir_option
      ].freeze
      DESCRIPTION = "Generates terraform configuration files"
      LONG_DESCRIPTION = <<~DESC
        - Generates terraform configuration files based on `controlplane.yml` and `templates/` config
      DESC
      WITH_INFO_HEADER = false

      def call
        Array(config.app || config.apps.keys).each do |app|
          config.instance_variable_set(:@app, app.to_s)
          generate_app_config
        end
      end

      private

      def generate_app_config
        copy_workload_module

        terraform_app_dir = cleaned_terraform_app_dir
        generate_provider_configs(terraform_app_dir)

        templates.each do |template|
          TerraformConfig::Generator.new(config: config, template: template).tf_configs.each do |filename, tf_config|
            File.write(terraform_app_dir.join(filename), tf_config.to_tf, mode: "a+")
          end
        rescue TerraformConfig::Generator::InvalidTemplateError => e
          Shell.warn(e.message)
        end
      end

      def copy_workload_module
        FileUtils.copy_entry(
          Cpflow.root_path.join("lib/core/terraform_config/workload"),
          terraform_dir.join("workload")
        )
      end

      def generate_provider_configs(terraform_app_dir)
        generate_required_providers(terraform_app_dir)
        generate_providers(terraform_app_dir)
      rescue StandardError => e
        Shell.abort("Failed to generate provider config files: #{e.message}")
      end

      def generate_required_providers(terraform_app_dir)
        File.write(terraform_app_dir.join("required_providers.tf"), required_cpln_provider.to_tf)
      end

      def generate_providers(terraform_app_dir)
        cpln_provider = TerraformConfig::Provider.new(name: "cpln", org: config.org)
        File.write(terraform_app_dir.join("providers.tf"), cpln_provider.to_tf)
      end

      def required_cpln_provider
        TerraformConfig::RequiredProvider.new(
          name: "cpln",
          org: config.org,
          source: "controlplane-com/cpln",
          version: "~> 1.0"
        )
      end

      def cleaned_terraform_app_dir
        full_path = terraform_dir.join(config.app)

        unless File.expand_path(full_path).include?(Cpflow.root_path.to_s)
          Shell.abort("Directory to save terraform configuration files cannot be outside of current directory")
        end

        if Dir.exist?(full_path)
          clean_terraform_app_dir(full_path)
        else
          FileUtils.mkdir_p(full_path)
        end

        full_path
      end

      def clean_terraform_app_dir(terraform_app_dir)
        Dir.children(terraform_app_dir).each do |child|
          next if child == ".terraform.lock.hcl"

          FileUtils.rm_rf(terraform_app_dir.join(child))
        end
      end
    end
  end
end
