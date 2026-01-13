# ==========================================================
# TERRAFORM Konfiguration Woche 6 Projektaufgabe
# ==========================================================

provider "aws" {
  region = "us-east-1"                                      # Rechenzentrum-Region
}

# --- AUTOMATISCHE SUCHE NACH DEM BETRIEBSSYSTEM ---
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]                     # Sucht nach Amazon Linux 2023
  }
}

# --- SECURITY GROUP (Firewall) ---
resource "aws_security_group" "grocery_sg" {
  name        = "grocery-app-firewall"
  description = "Security Group for EC2 and RDS"

  ingress {
    from_port   = 22                                        # SSH
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80                                        # HTTP
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432                                      # PostgreSQL
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- EC2 INSTANCE (Server) ---
resource "aws_instance" "grocery_server" {
  ami           = data.aws_ami.latest_amazon_linux.id       # Nutzt die gefundene ID
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.grocery_sg.id]

  tags = {
    Name = "Grocery-Web-Server"
  }
}

# --- RDS INSTANCE (Datenbank) ---
resource "aws_db_instance" "grocery_db" {
  allocated_storage   = 10
  engine              = "postgres"
  engine_version      = "15"
  instance_class      = "db.t3.micro"
  db_name             = "grocerymate_db"
  username            = "grocery_user"
  password            = "sosollessein"
  skip_final_snapshot = true
  publicly_accessible = true
}

output "server_public_ip" {
  value = aws_instance.grocery_server.public_ip
}

output "database_endpoint" {
  value = aws_db_instance.grocery_db.endpoint
}