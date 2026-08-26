//! Pure Firebase ID-token parsing, signature verification, and claim validation.
//!
//! Network retrieval and isolate-lifetime caching live in `auth`; keeping this
//! module runtime-independent lets host tests exercise the security boundary.

use std::collections::HashMap;

use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use crypto_bigint::BoxedUint;
use rsa::pkcs1v15::VerifyingKey;
use rsa::signature::Verifier;
pub(crate) use rsa::RsaPublicKey;
use serde::Deserialize;
use sha2::Sha256;

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum VerifyError {
    #[error("the authorization header is missing or malformed")]
    MissingToken,
    #[error("the token is not a well-formed JWT")]
    Malformed,
    #[error("the token algorithm is not supported")]
    UnsupportedAlgorithm,
    #[error("no matching signing key was found")]
    UnknownKey,
    #[error("the token signature is invalid")]
    BadSignature,
    #[error("the token claims are invalid")]
    InvalidClaims,
    #[error("fetching signing keys failed")]
    KeySourceUnavailable,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FirebaseClaims {
    pub sub: String,
    pub email: Option<String>,
    pub name: Option<String>,
    pub picture: Option<String>,
}

/// Extracts the bearer token from an `authorization` header value.
pub fn bearer_token(header: Option<&str>) -> Result<&str, VerifyError> {
    let header = header.ok_or(VerifyError::MissingToken)?;
    let rest = header
        .strip_prefix("Bearer ")
        .or_else(|| header.strip_prefix("bearer "))
        .ok_or(VerifyError::MissingToken)?;
    if rest.is_empty() {
        return Err(VerifyError::MissingToken);
    }
    Ok(rest)
}

#[derive(Debug, Deserialize)]
struct JwtHeader {
    alg: String,
    kid: Option<String>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct RawClaims {
    sub: Option<String>,
    aud: Option<String>,
    iss: Option<String>,
    exp: Option<i64>,
    email: Option<String>,
    name: Option<String>,
    picture: Option<String>,
}

#[derive(Debug)]
pub(crate) struct DecodedJwt {
    pub(crate) kid: Option<String>,
    pub(crate) signing_input: Vec<u8>,
    pub(crate) signature: Vec<u8>,
    pub(crate) claims: RawClaims,
}

/// Splits and base64url-decodes a JWT's three segments without verifying
/// anything yet. Pure and independently testable.
pub(crate) fn decode_jwt(token: &str) -> Result<DecodedJwt, VerifyError> {
    let mut parts = token.split('.');
    let (Some(header_b64), Some(payload_b64), Some(signature_b64), None) =
        (parts.next(), parts.next(), parts.next(), parts.next())
    else {
        return Err(VerifyError::Malformed);
    };

    let header_bytes = URL_SAFE_NO_PAD
        .decode(header_b64)
        .map_err(|_| VerifyError::Malformed)?;
    let header: JwtHeader =
        serde_json::from_slice(&header_bytes).map_err(|_| VerifyError::Malformed)?;
    if header.alg != "RS256" {
        return Err(VerifyError::UnsupportedAlgorithm);
    }

    let payload_bytes = URL_SAFE_NO_PAD
        .decode(payload_b64)
        .map_err(|_| VerifyError::Malformed)?;
    let claims: RawClaims =
        serde_json::from_slice(&payload_bytes).map_err(|_| VerifyError::Malformed)?;

    let signature = URL_SAFE_NO_PAD
        .decode(signature_b64)
        .map_err(|_| VerifyError::Malformed)?;

    Ok(DecodedJwt {
        kid: header.kid,
        signing_input: format!("{header_b64}.{payload_b64}").into_bytes(),
        signature,
        claims,
    })
}

/// Verifies an RS256 signature over `signing_input` using `public_key`.
pub(crate) fn verify_signature(
    public_key: &RsaPublicKey,
    signing_input: &[u8],
    signature: &[u8],
) -> Result<(), VerifyError> {
    let verifying_key = VerifyingKey::<Sha256>::new(public_key.clone());
    let signature =
        rsa::pkcs1v15::Signature::try_from(signature).map_err(|_| VerifyError::BadSignature)?;
    verifying_key
        .verify(signing_input, &signature)
        .map_err(|_| VerifyError::BadSignature)
}

/// Confirms audience, issuer, subject, and expiry. `now` is injected so
/// tests can pin the clock instead of racing a live token's expiry.
pub(crate) fn validate_claims(
    claims: &RawClaims,
    project_id: &str,
    now_unix: i64,
) -> Result<FirebaseClaims, VerifyError> {
    let sub = claims
        .sub
        .as_deref()
        .filter(|sub| !sub.is_empty())
        .ok_or(VerifyError::InvalidClaims)?;
    if claims.aud.as_deref() != Some(project_id) {
        return Err(VerifyError::InvalidClaims);
    }
    let expected_issuer = format!("https://securetoken.google.com/{project_id}");
    if claims.iss.as_deref() != Some(expected_issuer.as_str()) {
        return Err(VerifyError::InvalidClaims);
    }
    let exp = claims.exp.ok_or(VerifyError::InvalidClaims)?;
    if exp <= now_unix {
        return Err(VerifyError::InvalidClaims);
    }
    Ok(FirebaseClaims {
        sub: sub.to_string(),
        email: claims.email.clone(),
        name: claims.name.clone(),
        picture: claims.picture.clone(),
    })
}

#[derive(Debug, Deserialize)]
struct JwkSet {
    keys: Vec<Jwk>,
}

#[derive(Debug, Deserialize)]
struct Jwk {
    kid: String,
    kty: String,
    n: String,
    e: String,
}

/// Builds an `RsaPublicKey` from a JWK's base64url-encoded modulus and
/// exponent. Pure and independently testable against a fixture JWK.
fn public_key_from_jwk(jwk: &Jwk) -> Result<RsaPublicKey, VerifyError> {
    if jwk.kty != "RSA" {
        return Err(VerifyError::UnknownKey);
    }
    let n = URL_SAFE_NO_PAD
        .decode(&jwk.n)
        .map_err(|_| VerifyError::UnknownKey)?;
    let e = URL_SAFE_NO_PAD
        .decode(&jwk.e)
        .map_err(|_| VerifyError::UnknownKey)?;
    RsaPublicKey::new(
        BoxedUint::from_be_slice_vartime(&n),
        BoxedUint::from_be_slice_vartime(&e),
    )
    .map_err(|_| VerifyError::UnknownKey)
}

pub(crate) fn parse_jwks(body: &str) -> Result<HashMap<String, RsaPublicKey>, VerifyError> {
    let set: JwkSet = serde_json::from_str(body).map_err(|_| VerifyError::KeySourceUnavailable)?;
    set.keys
        .iter()
        .map(|jwk| Ok((jwk.kid.clone(), public_key_from_jwk(jwk)?)))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use rsa::pkcs1v15::SigningKey;
    use rsa::pkcs8::DecodePrivateKey;
    use rsa::signature::{SignatureEncoding, Signer};
    use rsa::traits::PublicKeyParts;
    use rsa::RsaPrivateKey;

    const TEST_KEY_PEM: &str = include_str!("../testdata/test_rsa_key.pem");

    fn test_keypair() -> (RsaPrivateKey, RsaPublicKey) {
        let private = RsaPrivateKey::from_pkcs8_pem(TEST_KEY_PEM).expect("valid test key");
        let public = RsaPublicKey::from(&private);
        (private, public)
    }

    fn sign_token(private: &RsaPrivateKey, kid: &str, claims: serde_json::Value) -> String {
        let header = serde_json::json!({"alg": "RS256", "typ": "JWT", "kid": kid});
        let header_b64 = URL_SAFE_NO_PAD.encode(header.to_string());
        let payload_b64 = URL_SAFE_NO_PAD.encode(claims.to_string());
        let signing_input = format!("{header_b64}.{payload_b64}");
        let signing_key = SigningKey::<Sha256>::new(private.clone());
        let signature: rsa::pkcs1v15::Signature = signing_key.sign(signing_input.as_bytes());
        let signature_b64 = URL_SAFE_NO_PAD.encode(signature.to_bytes());
        format!("{signing_input}.{signature_b64}")
    }

    fn valid_claims(now: i64) -> serde_json::Value {
        serde_json::json!({
            "sub": "user-123",
            "aud": "pushlog-app",
            "iss": "https://securetoken.google.com/pushlog-app",
            "exp": now + 3600,
            "email": "user@example.test",
            "name": "Test Pusher",
            "picture": "https://example.test/photo.png",
        })
    }

    #[test]
    fn bearer_token_extracts_the_credential() {
        assert_eq!(bearer_token(Some("Bearer abc.def.ghi")), Ok("abc.def.ghi"));
    }

    #[test]
    fn bearer_token_rejects_missing_or_malformed_headers() {
        assert_eq!(bearer_token(None), Err(VerifyError::MissingToken));
        assert_eq!(
            bearer_token(Some("Basic abc")),
            Err(VerifyError::MissingToken)
        );
        assert_eq!(
            bearer_token(Some("Bearer ")),
            Err(VerifyError::MissingToken)
        );
    }

    #[test]
    fn decode_jwt_rejects_wrong_segment_counts() {
        assert_eq!(decode_jwt("only.two").unwrap_err(), VerifyError::Malformed);
        assert_eq!(decode_jwt("a.b.c.d").unwrap_err(), VerifyError::Malformed);
    }

    #[test]
    fn decode_jwt_rejects_non_rs256_algorithms() {
        let header = URL_SAFE_NO_PAD.encode(r#"{"alg":"none","typ":"JWT"}"#);
        let payload = URL_SAFE_NO_PAD.encode("{}");
        let token = format!("{header}.{payload}.");
        assert_eq!(
            decode_jwt(&token).unwrap_err(),
            VerifyError::UnsupportedAlgorithm
        );
    }

    #[test]
    fn public_key_from_jwk_rejects_non_rsa_keys() {
        let jwk = Jwk {
            kid: "k1".into(),
            kty: "EC".into(),
            n: "AQAB".into(),
            e: "AQAB".into(),
        };
        assert_eq!(
            public_key_from_jwk(&jwk).unwrap_err(),
            VerifyError::UnknownKey
        );
    }

    #[test]
    fn full_verification_round_trip_accepts_a_validly_signed_token() {
        let (private, public) = test_keypair();
        let now = 1_700_000_000;
        let token = sign_token(&private, "kid-1", valid_claims(now));
        let decoded = decode_jwt(&token).expect("well-formed token");
        assert_eq!(decoded.kid.as_deref(), Some("kid-1"));
        verify_signature(&public, &decoded.signing_input, &decoded.signature)
            .expect("signature verifies against the matching public key");
        let claims =
            validate_claims(&decoded.claims, "pushlog-app", now).expect("claims are valid");
        assert_eq!(claims.sub, "user-123");
        assert_eq!(claims.email.as_deref(), Some("user@example.test"));
    }

    #[test]
    fn verification_rejects_a_signature_from_the_wrong_key() {
        let (private, _public) = test_keypair();
        let (_other_private, other_public) = {
            // A second, differently-generated key: signatures made by
            // `private` must not verify against `other_public`.
            const OTHER_KEY_PEM: &str = include_str!("../testdata/test_rsa_key_2.pem");
            let other = RsaPrivateKey::from_pkcs8_pem(OTHER_KEY_PEM).expect("valid second key");
            let public = RsaPublicKey::from(&other);
            (other, public)
        };
        let now = 1_700_000_000;
        let token = sign_token(&private, "kid-1", valid_claims(now));
        let decoded = decode_jwt(&token).expect("well-formed token");
        assert_eq!(
            verify_signature(&other_public, &decoded.signing_input, &decoded.signature),
            Err(VerifyError::BadSignature)
        );
    }

    #[test]
    fn claims_are_rejected_for_wrong_audience() {
        let now = 1_700_000_000;
        let mut claims = valid_claims(now);
        claims["aud"] = serde_json::json!("someone-elses-project");
        let raw: RawClaims = serde_json::from_value(claims).unwrap();
        assert_eq!(
            validate_claims(&raw, "pushlog-app", now).unwrap_err(),
            VerifyError::InvalidClaims
        );
    }

    #[test]
    fn claims_are_rejected_for_wrong_issuer() {
        let now = 1_700_000_000;
        let mut claims = valid_claims(now);
        claims["iss"] = serde_json::json!("https://securetoken.google.com/someone-else");
        let raw: RawClaims = serde_json::from_value(claims).unwrap();
        assert_eq!(
            validate_claims(&raw, "pushlog-app", now).unwrap_err(),
            VerifyError::InvalidClaims
        );
    }

    #[test]
    fn claims_are_rejected_once_expired() {
        let now = 1_700_000_000;
        let mut claims = valid_claims(now);
        claims["exp"] = serde_json::json!(now - 1);
        let raw: RawClaims = serde_json::from_value(claims).unwrap();
        assert_eq!(
            validate_claims(&raw, "pushlog-app", now).unwrap_err(),
            VerifyError::InvalidClaims
        );
    }

    #[test]
    fn claims_are_rejected_for_empty_subject() {
        let now = 1_700_000_000;
        let mut claims = valid_claims(now);
        claims["sub"] = serde_json::json!("");
        let raw: RawClaims = serde_json::from_value(claims).unwrap();
        assert_eq!(
            validate_claims(&raw, "pushlog-app", now).unwrap_err(),
            VerifyError::InvalidClaims
        );
    }

    #[test]
    fn claims_are_rejected_when_subject_is_missing() {
        let now = 1_700_000_000;
        let mut claims = valid_claims(now);
        claims.as_object_mut().unwrap().remove("sub");
        let raw: RawClaims = serde_json::from_value(claims).unwrap();
        assert_eq!(
            validate_claims(&raw, "pushlog-app", now).unwrap_err(),
            VerifyError::InvalidClaims
        );
    }

    #[test]
    fn parse_jwks_builds_a_key_per_kid() {
        let (_private, public) = test_keypair();
        let n = URL_SAFE_NO_PAD.encode(public.n().to_be_bytes());
        let e = URL_SAFE_NO_PAD.encode(public.e().to_be_bytes());
        let body = serde_json::json!({
            "keys": [{"kid": "kid-1", "kty": "RSA", "alg": "RS256", "n": n, "e": e}]
        })
        .to_string();
        let keys = parse_jwks(&body).expect("parses successfully");
        assert!(keys.contains_key("kid-1"));
    }

    #[test]
    fn parse_jwks_rejects_malformed_bodies() {
        assert_eq!(
            parse_jwks("not json").unwrap_err(),
            VerifyError::KeySourceUnavailable
        );
    }

    /// A live snapshot of Google's JWKS response (fetched during
    /// development; see `testdata/real_google_jwks_fixture.json`), so this
    /// module is proven against the actual field set and encoding Google
    /// serves — `use`/`alg` fields included — not only a hand-built one.
    #[test]
    fn parse_jwks_handles_a_real_google_response() {
        let body = include_str!("../testdata/real_google_jwks_fixture.json");
        let keys = parse_jwks(body).expect("parses Google's real response shape");
        assert_eq!(keys.len(), 4);
        assert!(keys.contains_key("27c45548555561960f491d50639e55657b212abc"));
    }
}
