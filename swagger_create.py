from pathlib import Path

# Define the OpenAPI YAML content for the Fund Transfer API
swagger_yaml = """
openapi: 3.0.1
info:
  title: Fund Transfer API
  description: API for handling fund transfers with JWT authentication
  version: "1.0.0"
servers:
  - url: http://localhost:8080
paths:
  /api/auth/register:
    post:
      summary: Register a new user
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/RegisterRequest'
      responses:
        '200':
          description: User registered
  /api/auth/login:
    post:
      summary: Authenticate user and return JWT token
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/LoginRequest'
      responses:
        '200':
          description: JWT token returned
  /api/fund-transfer:
    post:
      summary: Transfer funds from one account to another
      security:
        - bearerAuth: []
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/FundTransferRequest'
      responses:
        '200':
          description: Fund transfer successful
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
  schemas:
    RegisterRequest:
      type: object
      properties:
        username:
          type: string
        password:
          type: string
    LoginRequest:
      type: object
      properties:
        username:
          type: string
        password:
          type: string
    FundTransferRequest:
      type: object
      properties:
        fromAccountId:
          type: integer
        toAccountId:
          type: integer
        amount:
          type: number
          format: double
"""

# Write the YAML content to a file
output_path = Path("/mnt/data/fund-transfer-api.yaml")
output_path.write_text(swagger_yaml.strip())

output_path.name
