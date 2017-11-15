class RecognitionWorker
  include Sidekiq::Worker

  def perform(image_id)
    image = Image.find(image_id)
    return if image.image_metadata.where(key: :face).exists?

    res = client.detect_faces(image: { bytes: get_body(image) })

    value = res.to_h[:face_details].present? ? res.to_h.to_json : nil
    image.image_metadata.create!(
      key: :face,
      value: value
    )

    if value.present?
      setting = image.space.space_setting
      return unless setting&.slack_incoming_webhook_url

      SlackNotificationWorker.perform_async(image.id)
    end
  end

  def get_body(image)
    image.s3_object.get.body
  end

  private
  def client
    @client ||= Aws::Rekognition::Client.new(region: 'us-west-2')
  end
end
