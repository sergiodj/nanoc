# frozen_string_literal: true

describe 'manifest', chdir: false do
  example do
    expect('nanoc-cli').to have_a_valid_manifest
  end
end
