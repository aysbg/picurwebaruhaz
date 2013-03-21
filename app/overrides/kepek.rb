Deface::Override.new(:virtual_path => "spree/admin/images/index",
                 :name         => "fix_product_images_in_admin",
                 :replace      => "code[erb-silent]:contains('unless @product.images.any?')",
                 :text         => "<% unless @product.images.any? or @product.variants.collect(&:images).any? %>")
