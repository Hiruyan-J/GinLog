cloudinary_url = Rails.application.credentials.dig(:cloudinary, :url)
Cloudinary.config_from_url(cloudinary_url) if cloudinary_url.present?
