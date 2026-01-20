# 1. Die IAM Rolle erstellen (Entspricht: "Create Role" & "Select EC2")
resource "aws_iam_role" "grocery_ec2_role" {
  name = "grocery-ec2-role"

  # Erlaubt dem EC2-Dienst, diese Rolle anzunehmen
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 2. Die S3-FullAccess Policy anhängen (Entspricht: "Attach AmazonS3FullAccess")
resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.grocery_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# 3. Das Instanz-Profil erstellen (Wichtig: Das ist das Verbindungsstück zur EC2)
resource "aws_iam_instance_profile" "grocery_ec2_profile" {
  name = "grocery-ec2-instance-profile"
  role = aws_iam_role.grocery_ec2_role.name
}