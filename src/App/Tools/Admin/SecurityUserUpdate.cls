/// generated, dont edit by hand
Class App.Tools.Admin.SecurityUserUpdate Extends App.Tools.AdminBase
{

Parameter ToolName = "security.user.update";

Parameter Title = "Edit a user";

Parameter Category = "security";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "PUT";

Parameter HttpPath = "/v2/security/user";

Parameter QueryArgs = "name";

Parameter Privilege = "%Admin_Secure:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "name": {
        "type": "string",
        "title": "Name of a User"
      },
      "AccountNeverExpires": {
        "description": "Account Expiration behavior. False - Account expires normally. True - Account will never expire.",
        "type": "boolean"
      },
      "AutheEnabled": {
        "description": "Two factor Authentication options which are enabled for this user. Options are:<br>2**20 - SMS Text authentication.<br>2**21 - Time-based One-time Password",
        "type": "integer"
      },
      "ChangePassword": {
        "description": "Change password on next login. False - Password change not required. True - Password change required before next login.",
        "type": "boolean"
      },
      "Comment": {
        "description": "Comment.",
        "type": "string"
      },
      "EmailAddress": {
        "description": "Email address of the user.",
        "type": "string",
        "example": "user@company.com"
      },
      "Enabled": {
        "description": "Allow user to log in. False - Disable login. True - Enable login.",
        "type": "boolean"
      },
      "ExpirationDate": {
        "description": "Last date an account can be used. If there is no limit, this value may be 1840-12-31 or \"\"",
        "type": "string",
        "example": "2027-12-31"
      },
      "FullName": {
        "description": "Full name of the user.",
        "type": "string",
        "example": "First Last"
      },
      "HOTPKeyDisplay": {
        "description": "Display the Time-based One-time Password QR code or key on next login for the user to scan with their authentication device.",
        "type": "boolean"
      },
      "NameSpace": {
        "description": "NameSpace to run in only if a terminal session.",
        "type": "string",
        "example": "USER"
      },
      "PasswordNeverExpires": {
        "description": "Password expires behavior. False - Password expires normally. True - Password never expires.",
        "type": "boolean"
      },
      "PhoneNumber": {
        "description": "Phone number for two-factor authentication",
        "type": "string",
        "example": "123-456-7890"
      },
      "PhoneProvider": {
        "description": "Mobile phone service provider for two-factor authentication",
        "type": "string"
      },
      "Roles": {
        "description": "Roles assigned to the user.",
        "type": "array",
        "items": {
          "type": "string",
          "example": "%All"
        }
      },
      "EscalationRoles": {
        "description": "",
        "type": "array",
        "items": {
          "type": "string",
          "example": "%All"
        }
      },
      "Routine": {
        "description": "Routine to run only if terminal session, \"\"=Programmer mode.",
        "type": "string",
        "example": ""
      }
    },
    "required": [
      "name"
    ]
  }
}

}
