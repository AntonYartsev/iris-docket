/// generated, dont edit by hand
Class App.Tools.Admin.WebappUpdate Extends App.Tools.AdminBase
{

Parameter ToolName = "webapp.update";

Parameter Title = "Edit a web application";

Parameter Category = "web-app";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "PUT";

Parameter HttpPath = "/v2/web-app";

Parameter QueryArgs = "name";

Parameter Privilege = "%Admin_Secure:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "name": {
        "type": "string",
        "title": "Web app name"
      },
      "AutheEnabled": {
        "description": "Authentication and Session mechanisms enabled. Note that these bits correspond to the same bit numbers in the Security.System class<br>Bit 2 = AutheK5API<br>Bit 5 - AuthePassword<br>Bit 6 = AutheUnauthenticated<br>Bit 11 = AutheLDAP<br>Bit 13 = AutheDelegated<br>Bit 14 = LoginToken<br>Bit 20 = TwoFactorSMS<br>Bit 21 = TwoFactorPW",
        "type": "integer"
      },
      "AutoCompile": {
        "description": "This specifies whether CSP files should automatically compile or not. If this is turned on, then when a CSP file is more recent than its compiled class,<br>it is recompiled. This is normally something you would turn on in development environments<br>and turn off in production environments.",
        "type": "boolean"
      },
      "ChangePasswordPage": {
        "description": "A predefined change password page that can be sent out to the browser if the user account requires that a password change is required.",
        "type": "string"
      },
      "CookiePath": {
        "description": "Scope of the session cookie. This determines which urls the browser will send the session cookie back to InterSystems IRIS. If your application name is 'myapp', it defaults to '/myapp/' meaning it will only send<br>the cookie for pages under '/myapp/'. You should restrict this to only what is required<br>by your application to prevent this session cookie being used by other CSP application<br>on this machine, or from being seen by any other application on this web server",
        "type": "string"
      },
      "CorsAllowlist": {
        "description": "List of Origins for CORS policies. This is an allowlist",
        "type": "array",
        "items": {
          "type": "string"
        }
      },
      "CorsCredentialsAllowed": {
        "description": "If true, Access-Control-Allow-Credentials header will be included in CORS-enabled responses.",
        "type": "boolean"
      },
      "CorsHeadersList": {
        "description": "List of custom headers to include when CORS is enabled.",
        "type": "array",
        "items": {
          "type": "string"
        }
      },
      "CSPZENEnabled": {
        "description": "Indicates whether this application will process CSP/Zen Pages.",
        "type": "boolean"
      },
      "CSRFToken": {
        "description": "Prevent login CSRF attack. When enabled generate a token and cookie in the login page that is validated before accepting any username/password. Enabling this will prevent programmatic access to pages in this application that just pass in the username/password on the initial request. It also prevents the use of the CSPSHARE=1 URL Parameter to pass the session token in the URL when cookies are required for the application.",
        "type": "boolean"
      },
      "DeepSeeEnabled": {
        "description": "Indicates whether DeepSee access is enabled for this application.",
        "type": "boolean"
      },
      "Description": {
        "description": "Application description.",
        "type": "string"
      },
      "DispatchClass": {
        "description": "If defined this will dispatch all requests in this CSP application to this one class. This will bypass the normal url to classname conversion so allowing the specified class complete control over this dispatch of the page. A predefined dispatch class that can be used is 'CSP.REST' which provides REST dispatch capabilities. For REST Web Application only.",
        "type": "string"
      },
      "Enabled": {
        "description": "Application is enabled.",
        "type": "boolean"
      },
      "ErrorPage": {
        "description": "A CSP or CLS page that will be displayed if an error occurs when generating the page.",
        "type": "string"
      },
      "EventClass": {
        "description": "This specifies the class whose methods are invoked for CSP application events,<br>such as a timeout.",
        "type": "string"
      },
      "GroupById": {
        "description": "Indicates whether this application's authentication will move in sync with other applications in the same id group.",
        "type": "string"
      },
      "iKnowEnabled": {
        "description": "Indicates whether iKnow access is enabled for this application. Like the DeepSeeEnabled property, this corresponds with the Analytics option shown in Management Portal.",
        "type": "boolean"
      },
      "InbndWebServicesEnabled": {
        "description": "Indicates whether this application will process Web Services. Corresponds with the \"Inbound Web Services\" option shown in Management Portal.",
        "type": "boolean"
      },
      "IsNameSpaceDefault": {
        "description": "Indicates that this application is the default application for its namespace. As such it will be returned by the call $System.CSP.GetDefaultApp().",
        "type": "boolean"
      },
      "JWTAuthEnabled": {
        "description": "Indicates that this application uses JWT Bearer tokens for authentication. For REST Web Application only",
        "type": "boolean"
      },
      "JWTAccessTokenTimeout": {
        "description": "Specifies the timeout (in seconds) for JWT Access Tokens. This is only relevant for REST Web Applications where <i>JWTAuthEnabled</i> is true.",
        "type": "integer"
      },
      "JWTRefreshTokenTimeout": {
        "description": "Specifies the timeout (in seconds) for JWT Refresh Tokens. This is only relevant for REST Web Applications where <i>JWTAuthEnabled</i> is true.",
        "type": "integer"
      },
      "LockCSPName": {
        "description": "Lock CSP Name. If true, then you can only access this CSP page if the url you enter matches the url stored in the CSPURL parameter value in the class. CSP pages have the CSPURL set to the original url requested automatically when they are compiled. If the url does not match, you get a page not found error. For example if you have two CSP applications defined that both map to the same namespace and the same directory '/A' and '/B'. Then you view '/A/page.csp' this will load this page and create the class 'csp.page' with the CSPURL parameter set to '/A/page.csp'. With this flag set you may only access this page using the url '/A/page.csp'. If this flag is false you may access it via the pages '/B/page.csp', '/A/csp.page.cls', '/B/csp.page.cls'.  Note that the flag is checked on the application associated with the CSPURL parameter, so even if the '/B' application has the flag turned off, if the '/A' application has it turned on you will get a page not found error from '/B/page.csp'. If you modify the CSP class and change the CSPURL=\"\" then this disables checking for this page.",
        "type": "boolean"
      },
      "LoginPage": {
        "description": "A predefined login page that can be sent out to the browser if the application requires<br> an authenticated identity and one is not available yet",
        "type": "string"
      },
      "MatchRoles": {
        "description": "Mapping of MatchRole/TargetRoles pairs to assign to the application<br>To specify a role to always be granted to an application, set MatchRole=\"\"",
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "MatchRole": {
              "type": "string"
            },
            "TargetRoles": {
              "type": "array",
              "items": {
                "type": "string",
                "example": "%All"
              }
            }
          }
        }
      },
      "NameSpace": {
        "description": "The namespace where pages for this application are run. Required on creation, optional on updates.",
        "type": "string",
        "example": "%SYS"
      },
      "Package": {
        "description": "Specifies the package to prefix to the class name for all CSP files in this application. If not specified it defaults to \"csp\"",
        "type": "string",
        "example": "csp"
      },
      "Path": {
        "description": "This specifies the physical path (directory) for the CSP files on the InterSystems IRIS server.",
        "type": "string",
        "example": "/Users/user/iris/my-app"
      },
      "PermittedClasses": {
        "description": "A name pattern which is used to limit the classes which may be run in this application. This is an ObjectScript pattern. For example: 1(1\"B\",1\"A\".1N) matches {B.cls, A0.cls ... A9.cls}",
        "type": "string"
      },
      "Recurse": {
        "description": "This specifies whether to use subdirectories. If WPath is the Web Path and PPath is the Physical Path, then with recurse turned on,<br>WPath/xxx/yyy will look in PPath/xxx/yyy. If recurse is turned off, only files directly<br>contained in WPath are used.",
        "type": "boolean"
      },
      "RedirectEmptyPath": {
        "description": "This specifies whether to use FHIR-standard redirects of empty paths. For REST Web Application only. For example, if the request is for WPath/csp/appname and the app /csp/appname/<br>has this property enabled, then instead of serving the request with the next level down (csp, if it exists), the request will be served by /csp/appname/.",
        "type": "boolean"
      },
      "Resource": {
        "description": "The Resource name that controls access to this application. If no resource is defined, then it is a public application which anyone can run",
        "type": "string",
        "example": "%Admin_Operate"
      },
      "ServeFiles": {
        "description": "Allows the web server built into InterSystems IRIS to serve up static files, e.g., html or jpg files, from this application path. This also allows the stream server to serve files from this path.",
        "type": "string",
        "enum": [
          "Never",
          "Always",
          "Always and cached",
          "Use CSP security"
        ]
      },
      "ServeFilesTimeout": {
        "description": "Time, in seconds, of how long to cache static files",
        "type": "integer"
      },
      "SuperClass": {
        "description": "This specifies the default superclass. If blank, it defaults to %CSP.Page",
        "type": "string",
        "example": "%CSP.Page"
      },
      "Timeout": {
        "description": "This specifies the default session timeout, in seconds",
        "type": "integer"
      },
      "TraceEnabled": {
        "description": "This specifies if automated OTel Traces are enabled for this Application. Only used for CSP/SOAP and REST Web Services.",
        "type": "boolean"
      },
      "TwoFactorEnabled": {
        "description": "This specifies whether to use two-factor authentication for this application. Two Factor Authentication is used with Password authentication which causes a security token to be sent to the user. To complete authentication the user must enter the security token.",
        "type": "boolean"
      },
      "Type": {
        "description": "Type - Bitmap describing the type of application<br>Bit 0 = System Application - Reserved.<br>Bit 1 = CSP/REST Web Application (Default)<br>Bit 2 = Privileged routine application<br>Bit 3 = DocDB/Client Application",
        "type": "integer"
      },
      "UseCookies": {
        "description": "This specifies whether to use cookies for CSP session management or not. For REST and CSP Web Application only. You can set this on a per-application basis. It does NOT affect the user's use of<br>cookies in their application, simply how the session is managed.",
        "type": "string",
        "enum": [
          "Never",
          "AutoDetect",
          "Always"
        ]
      },
      "SessionScope": {
        "description": "SameSite value that is used for CSP Session cookies. For REST and CSP Web Application only. This setting affects whether session cookies are sent for cross-site requests. The default setting for a new application is Strict.",
        "type": "string",
        "enum": [
          "None",
          "Lax",
          "Strict"
        ]
      },
      "UserCookieScope": {
        "description": "Default SameSite value for cookies created by users' calls to %CSP.Response.SetCookie(). For REST and CSP Web Application only. This setting affects whether session cookies are sent for cross-site requests. <br>Users can override the default by specifying the SameSite value in their SetCookie call.",
        "type": "string",
        "enum": [
          "None",
          "Lax",
          "Strict"
        ]
      },
      "WSGIAppLocation": {
        "description": "This is the path of the directory containing the python application",
        "type": "string",
        "example": "/Users/user/python-app/"
      },
      "WSGIAppName": {
        "description": "This is the name of the WSGI-compliant python application (e.g flask_app)",
        "type": "string"
      },
      "WSGICallable": {
        "description": "This is the name of the WSGI application callable.",
        "type": "string"
      },
      "WSGIDebug": {
        "description": "This describes if the WSGI application is in Debug Mode",
        "type": "boolean"
      },
      "WSGIType": {
        "description": "This determines if the application is WSGI or ASGI compliant.",
        "type": "integer"
      }
    },
    "required": [
      "name"
    ]
  }
}

}
