# Infrastructure for GroceryMate
# Created by: Youssef El Maach
# Tools: Terraform, AWS (EC2, RDS, S3, Lambda, SNS)

# ==========================================================
# TERRAFORM Konfiguration Projektaufgabe
# ==========================================================

# Legt den Cloud-Anbieter fest (hier AWS) und die Region für die Ressourcen
provider "aws" {
  region = "eu-central-1"                                      # Rechenzentrum-Region: Frankfurt
}

# --- AUTOMATISCHE SUCHE NACH DEM BETRIEBSSYSTEM ---
# Diese Abfrage sucht dynamisch nach dem aktuellsten Amazon Linux Image (AMI)
data "aws_ami" "latest_amazon_linux" {
  most_recent = true                                           # Nimm die neueste Version
  owners      = ["amazon"]                                     # Nur offizielle Images von Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]                       # Filtert nach dem Namen für Amazon Linux 2023
  }
}

# --- SECURITY GROUP (Firewall) ---
# Definiert die Ein- und Ausgangsregeln für den Netzwerkverkehr
resource "aws_security_group" "grocery_sg" {
  name        = "grocery-app-firewall"
  description = "Security Group for EC2 and RDS"

  # Eingehender Verkehr: Erlaubt Fernwartung über SSH
  ingress {
    from_port   = 22                                           # Port 22 für SSH-Zugriff
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]                                # Erlaubt Zugriff von jeder IP-Adresse
  }

  # Eingehender Verkehr: Erlaubt Web-Zugriff über HTTP
  ingress {
    from_port   = 80                                           # Port 80 für Webserver
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Eingehender Verkehr: Erlaubt Zugriff auf die PostgreSQL Datenbank
  ingress {
    from_port   = 5432                                         # Standard-Port für PostgreSQL
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ausgehender Verkehr: Erlaubt dem Server, alles im Internet zu erreichen
  egress {
    from_port   = 0                                            # Alle Ports
    to_port     = 0
    protocol    = "-1"                                         # Alle Protokolle
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- EC2 INSTANCE (Server) ---
# Erstellt den eigentlichen virtuellen Server
resource "aws_instance" "grocery_server" {
  ami           = data.aws_ami.latest_amazon_linux.id          # Verweist auf das oben gefundene Betriebssystem
  instance_type = "t2.micro"                                   # Die Instanzgröße (im Free Tier enthalten)
  vpc_security_group_ids = [aws_security_group.grocery_sg.id]  # Verknüpft die Firewall mit dem Server

  iam_instance_profile = aws_iam_instance_profile.grocery_ec2_profile.name

key_name = "startkey"

  tags = {
    Name = "Grocery-Web-Server"                                # Name des Servers in der AWS-Konsole
  }
}

# --- RDS INSTANCE (Datenbank) ---
# Erstellt eine verwaltete PostgreSQL-Datenbank
resource "aws_db_instance" "grocery_db" {
  allocated_storage   = 10                                  # Speicherplatz in Gigabyte (GB)
  engine              = "postgres"                          # Datenbank-System
  engine_version      = "15"                                # Version von PostgreSQL
  instance_class      = "db.t3.micro"                       # Hardware-Leistung der Datenbank
  db_name             = "grocerymate_db"                    # Name der ersten Datenbank, die erstellt wird
  username            = "grocery_user"                      # Administrator-Benutzername
  password            = var.db_password                      # Administrator-Passwort
  skip_final_snapshot = true                                # Erstellt beim Löschen kein Backup (spart Zeit/Kosten im Test)
  publicly_accessible = true                                # Datenbank ist über das Internet erreichbar
}

# --- AUSGABEWERTE ---
# Zeigt nach dem "terraform apply" wichtige Informationen direkt im Terminal an

# Gibt die öffentliche IP-Adresse des Servers aus, um ihn aufzurufen
output "server_public_ip" {
  value = aws_instance.grocery_server.public_ip
}

# Gibt die Adresse (URL) der Datenbank aus
output "database_endpoint" {
  value = aws_db_instance.grocery_db.endpoint
}



# --- VPC ENDPOINT FÜR S3 ---
# Ermöglicht der EC2-Instanz den Zugriff auf S3-Buckets über das private AWS-Backbone-Netzwerk.
# Dies erhöht die Sicherheit, da der Datenverkehr nicht über das öffentliche Internet läuft,
# und reduziert Latenzen – und das ohne zusätzliche Kosten.
resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id       = data.aws_vpc.default.id
  service_name = "com.amazonaws.eu-central-1.s3"

  # Injiziert die S3-Präfixliste automatisch in die Standard-Routentabelle
  route_table_ids = [data.aws_route_table.default.id]

  tags = {
    Name        = "grocery-s3-gateway-endpoint"
    Environment = "Production"
  }
}

# --- DATENQUELLE FÜR ROUTENTABELLE ---
# Ruft dynamisch die ID der Standard-Routentabelle ab, die für die
# Verknüpfung des Gateway-Endpoints benötigt wird.
data "aws_route_table" "default" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "default-route-table"
    values = ["true"]
  }
}

# --- DATENQUELLE FÜR DAS VPC ---
# Ruft die Informationen des Standard-VPC ab, in dem die Ressourcen erstellt werden.
data "aws_vpc" "default" {
  default = true
}