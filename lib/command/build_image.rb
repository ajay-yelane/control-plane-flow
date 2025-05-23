# frozen_string_literal: true

module Command
  class BuildImage < Base
    NAME = "build-image"
    OPTIONS = [
      app_option(required: true),
      commit_option,
      docker_context_option
    ].freeze
    ACCEPTS_EXTRA_OPTIONS = true
    DESCRIPTION = "Builds and pushes the image to Control Plane"
    LONG_DESCRIPTION = <<~DESC
      - Builds and pushes the image to Control Plane
      - Automatically assigns image numbers, e.g., `app:1`, `app:2`, etc.
      - Uses `.controlplane/Dockerfile` or a different Dockerfile specified through `dockerfile` in the `.controlplane/controlplane.yml` file
      - If a commit is provided through `--commit` or `-c`, it will be set as the runtime env var `GIT_COMMIT`
      - Accepts extra options that are passed to `docker build`
    DESC

    def call # rubocop:disable Metrics/MethodLength
      ensure_docker_running!

      dockerfile = config.current[:dockerfile] || "Dockerfile"
      dockerfile = "#{config.app_cpln_dir}/#{dockerfile}"

      raise "Can't find Dockerfile at '#{dockerfile}'." unless File.exist?(dockerfile)

      progress.puts("Building image from Dockerfile '#{dockerfile}'...\n\n")

      image_name = cp.latest_image_next
      image_url = "#{config.org}.registry.cpln.io/#{image_name}"

      commit = config.options[:commit]
      build_args = []
      build_args.push("GIT_COMMIT=#{commit}") if commit

      docker_context = config.options[:docker_context] || config.app_dir

      cp.image_build(image_url, dockerfile: dockerfile,
                                docker_args: config.args,
                                build_args: build_args,
                                docker_context: docker_context)

      push_path = "/org/#{config.org}/image/#{image_name}"

      progress.puts("\nPushing image to '#{push_path}'...\n\n")
      cp.image_push(image_url)
      progress.puts("\nPushed image to '#{push_path}'.\n\n")

      step("Waiting for image to be available", retry_on_failure: true) do
        images = cp.query_images["items"]
        images.find { |image| image["name"] == image_name }
      end
    end
  end
end
