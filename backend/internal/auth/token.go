// Package auth emite e valida os tokens de sessão (JWT HS256).
package auth

import (
	"errors"
	"strconv"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var ErrTokenInvalido = errors.New("token inválido")

type Claims struct {
	UsuarioID int64
	EmitidoEm time.Time
}

type Emissor struct {
	segredo  []byte
	validade time.Duration
	agora    func() time.Time
}

func NovoEmissor(segredo string, validade time.Duration) *Emissor {
	return &Emissor{segredo: []byte(segredo), validade: validade, agora: time.Now}
}

// Emitir devolve o token e o instante em que ele expira.
func (e *Emissor) Emitir(usuarioID int64) (string, time.Time, error) {
	agora := e.agora()
	expira := agora.Add(e.validade)
	token, err := e.assinar(strconv.FormatInt(usuarioID, 10), agora, expira)
	return token, expira, err
}

func (e *Emissor) assinar(sub string, emitido, expira time.Time) (string, error) {
	return jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.RegisteredClaims{
		Subject:   sub,
		IssuedAt:  jwt.NewNumericDate(emitido),
		ExpiresAt: jwt.NewNumericDate(expira),
	}).SignedString(e.segredo)
}

func (e *Emissor) Validar(token string) (Claims, error) {
	var rc jwt.RegisteredClaims
	_, err := jwt.ParseWithClaims(token, &rc,
		func(*jwt.Token) (any, error) { return e.segredo, nil },
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
		jwt.WithExpirationRequired(),
		jwt.WithIssuedAt(),
		jwt.WithTimeFunc(e.agora),
	)
	if err != nil || rc.IssuedAt == nil {
		return Claims{}, ErrTokenInvalido
	}
	id, err := strconv.ParseInt(rc.Subject, 10, 64)
	if err != nil {
		return Claims{}, ErrTokenInvalido
	}
	return Claims{UsuarioID: id, EmitidoEm: rc.IssuedAt.Time}, nil
}
