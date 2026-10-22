# frozen_string_literal: true

# Prepended to Turbo::StreamsChannel (config/initializers/turbo_stream_authorization.rb): a subscription is
# accepted only for streams that belong to the connected user. Every stream this app broadcasts on starts with
# its owner, e.g. [user, :wardrobe] (Phase 3: :planner, Phase 4: :avatar), so its first part must be the
# connection's current_user. Anything else is rejected, even with a valid signature.
module UserStreamAuthorization
  def subscribed
    return reject unless stream_owned_by_current_user?

    super
  end

  private

  def stream_owned_by_current_user?
    stream_name = verified_stream_name_from_params
    return false unless stream_name && current_user

    owner = GlobalID.parse(stream_name.split(":").first)
    owner.present? && owner.model_name == "User" && owner.model_id == current_user.id.to_s
  end
end
