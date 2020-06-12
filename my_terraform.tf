//region and profile

provider "aws" {
  region = "ap-south-1"
  profile = "rithwik"
}

//variables

variable "KEY_NAME" {
	type = string
	default = "tfkey"
}
variable "AMI" {
	type = string
	default = "ami-0447a12f28fddb066"
}

//creating key

resource "aws_key_pair" "KEY" {
  key_name   = var.KEY_NAME
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAq7JaC8ovfQK2uE/YOxp1i17oHw5XImvXKPzuTLGzp9TpDpJRW+EkQaskCodLKwZKh33292brkAsLyfRRQKRkFrWnFhqW62Zlb0FTXTvtdg2EgE5V2I3ZcRXM3x+l773WGFvgsAYzftZghYLDQcNT86AaArEJ3Pe6ezGXD55RbJYdc0nFuS/HOccmX/3rZCkXHDKNv/IZkTc3B+QuMmVeOvZfjefDECTiFvh2kYLGWJ31OWHr7BP9cAW20DV7/KkvMJ0Z73+P/CGb8/xLEob7lJc/png5Qz0jVvutqQOM5KK7mBQqG/incqX6sckWsKBPxQad2kRL9twmAOFjnAOAmQ== rsa-key-20200610"
}

//creating security group

resource "aws_security_group" "customtcp" {
  name        = "tfserver"
  description = "Allow TCP inbound traffic"
  vpc_id      = "vpc-c9e9f4a1"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

tags = {
    Name = "ALLOW TCP"
  }
}

//creating EC2 instance

resource "aws_instance" "web" {
  ami           = var.AMI
  instance_type = "t2.micro"
  key_name = var.KEY_NAME
  security_groups = ["tfserver"]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:\\Users\\yalla\\Desktop\\tfkey.pem")
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  
  tags = {
    Name = "TERRAFORM"
  }
}

//creating ebs volume

resource "aws_ebs_volume" "MY_VOL1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1

  tags = {
    Name = "TERRAFORM_VOL"
  }
}

//attaching ebs to EC2 instance

resource "aws_volume_attachment" "EBS_ATTACH" {
  depends_on = [ 
         aws_ebs_volume.MY_VOL1,
  ]
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.MY_VOL1.id
  instance_id = aws_instance.web.id
  force_detach= true
}

//creating S3 bucket

resource "aws_s3_bucket" "TERRAFORM_S3" {
  
  acl    = "public-read"
  versioning {
enabled=true
}
}

//creating S3 bucket_object

resource "aws_s3_bucket_object" "object" {
  bucket = aws_s3_bucket.TERRAFORM_S3.bucket
  key    = "WEB_IMAGE"
  acl = "public-read"
  source="C:\\Users\\yalla\\Desktop\\test.jpg"
  etag = filemd5("C:\\Users\\yalla\\Desktop\\test.jpg")
}

// creating cloudfront for s3 bucket

resource "aws_cloudfront_distribution" "s3_distribution" {
depends_on = [
   null_resource.nullremote3,
  ]
  origin {
    domain_name = aws_s3_bucket.TERRAFORM_S3.bucket_regional_domain_name
    origin_id   = "my_first_origin"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "TERRAFORM_IMAGE_IN_CF"
  default_root_object = "WEB_IMAGE"
    default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "my_first_origin"
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "my_first_origin"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "my_first_origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE","IN"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
connection {
        type    = "ssh"
        user    = "ec2-user"
        private_key = file("C:\\Users\\yalla\\Desktop\\tfkey.pem")
	host     = aws_instance.web.public_ip
    }
provisioner "remote-exec" {
        inline  = [
            # "sudo su << \"EOF\" \n echo \"<img src='${self.domain_name}'>\" >> /var/www/html/index.html \n \"EOF\""
            "sudo su << EOF",
            "echo \"<center><img src='http://${self.domain_name}/${aws_s3_bucket_object.object.key}' height='200px' width='200px'></center>\" >> /var/www/html/index.html",
            "EOF"
        ]
    }

}

//connect to instance and format,mount,download github code

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.EBS_ATTACH,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:\\Users\\yalla\\Desktop\\tfkey.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/rithwik12345/TERRAFORM_TASK1.git /var/www/html/",
    ]
  }
}

//launching chrome as soon as infrastructure is created

resource "null_resource" "nulllocal1"  {


depends_on = [
    null_resource.nullremote3,aws_cloudfront_distribution.s3_distribution
  ]

	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.web.public_ip}"
  	}
}
