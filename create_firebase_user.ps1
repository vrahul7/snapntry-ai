# Create Firebase Auth user via REST API using the Firebase Identity Toolkit
# API key from google-services.json

$apiKey = "AIzaSyD5FQb3X_sLP93LNg-W6dLz_PWC-1bWgYU"
$email = "vgrahul7@gmail.com"
$password = "12345679"

$signUpUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey"

Write-Host "Creating/verifying user: $email"

# First try to sign in to check if user exists
$signInUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey"
$signInBody = @{
    email = $email
    password = $password
    returnSecureToken = $true
} | ConvertTo-Json

try {
    $signInResult = Invoke-RestMethod -Uri $signInUrl -Method Post -Body $signInBody -ContentType "application/json" -ErrorAction Stop
    Write-Host "SUCCESS: User already exists and credentials are valid!"
    Write-Host "UID: $($signInResult.localId)"
    Write-Host "Email: $($signInResult.email)"
    exit 0
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $responseBody = $_.ErrorDetails.Message | ConvertFrom-Json
    $errorCode = $responseBody.error.message
    
    if ($errorCode -eq "EMAIL_NOT_FOUND" -or $errorCode -eq "INVALID_LOGIN_CREDENTIALS" -or $errorCode -like "*EMAIL_NOT_FOUND*") {
        Write-Host "User not found, creating new user..."
    } elseif ($errorCode -eq "INVALID_PASSWORD") {
        Write-Host "User exists but wrong password. Trying to reset..."
    } else {
        Write-Host "Sign-in error: $errorCode. Proceeding to create user..."
    }
}

# Create the user
$signUpBody = @{
    email = $email
    password = $password
    returnSecureToken = $true
} | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Uri $signUpUrl -Method Post -Body $signUpBody -ContentType "application/json" -ErrorAction Stop
    Write-Host "SUCCESS: User created!"
    Write-Host "UID: $($result.localId)"
    Write-Host "Email: $($result.email)"
    
    # Now sign in to confirm
    $confirmResult = Invoke-RestMethod -Uri $signInUrl -Method Post -Body $signInBody -ContentType "application/json" -ErrorAction Stop
    Write-Host "CONFIRMED: Login test successful with the new credentials."
    exit 0
} catch {
    $responseBody = $_.ErrorDetails.Message | ConvertFrom-Json
    $errorCode = $responseBody.error.message
    if ($errorCode -eq "EMAIL_EXISTS") {
        Write-Host "User already exists with that email. The password may be different."
        Write-Host "Please use the Firebase Console to reset: https://console.firebase.google.com/project/b2b-gena2z-prod-8898/authentication/users"
    } else {
        Write-Host "ERROR creating user: $errorCode"
        Write-Host $_.ErrorDetails.Message
    }
    exit 1
}
