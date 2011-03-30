MODULE = WWW::CurlOO	PACKAGE = WWW::CurlOO::Share	PREFIX = curl_share_

INCLUDE: const-share-xs.inc

PROTOTYPES: ENABLE

void
curl_share_new(...)
	PREINIT:
		perl_curl_share_t *self;
		char *sclass = "WWW::CurlOO::Share";
	PPCODE:
		/* {{{ */
		if (items>0 && !SvROK(ST(0))) {
			STRLEN dummy;
			sclass = SvPV(ST(0),dummy);
		}

		self=perl_curl_share_new();

		ST(0) = sv_newmortal();
		sv_setref_pv(ST(0), sclass, (void*)self);
		SvREADONLY_on(SvRV(ST(0)));

		XSRETURN(1);
		/* }}} */

void
curl_share_DESTROY(self)
	WWW::CurlOO::Share self
	CODE:
		perl_curl_share_delete( aTHX_ self );

int
curl_share_setopt(self, option, value)
	WWW::CurlOO::Share self
	int option
	SV * value
	CODE:
		/* {{{ */
		RETVAL=CURLE_OK;
		switch( option ) {
			case CURLSHOPT_LOCKFUNC:
				RETVAL = curl_share_setopt( self->curlsh, CURLSHOPT_LOCKFUNC, SvOK( value ) ? cb_share_lock : NULL );
				curl_share_setopt( self->curlsh, CURLSHOPT_USERDATA, SvOK( value ) ? self : NULL );
				perl_curl_share_register_callback( aTHX_ self, &(self->callback[CALLBACKSH_LOCK]), value );
				break;
			case CURLSHOPT_UNLOCKFUNC:
				RETVAL = curl_share_setopt( self->curlsh, CURLSHOPT_UNLOCKFUNC, SvOK(value) ? cb_share_unlock : NULL );
				curl_share_setopt( self->curlsh, CURLSHOPT_USERDATA, SvOK(value) ? self : NULL );
				perl_curl_share_register_callback( aTHX_ self, &(self->callback[CALLBACKSH_UNLOCK]), value );
				break;
			case CURLSHOPT_USERDATA:
				perl_curl_share_register_callback( aTHX_ self, &(self->callback_ctx[CALLBACKSH_LOCK]), value );
				break;
			case CURLSHOPT_SHARE:
			case CURLSHOPT_UNSHARE:
				RETVAL = curl_share_setopt( self->curlsh, option, (long)SvIV( value ) );
				break;
			default:
				croak("Unknown curl share option");
				break;
		};
		/* }}} */
	OUTPUT:
		RETVAL


SV *
curl_share_strerror(self, errornum)
	WWW::CurlOO::Share self
	int errornum
	PREINIT:
		const char *errstr;
	CODE:
		errstr = curl_share_strerror( errornum );
		RETVAL = newSVpv( errstr, 0 );
	OUTPUT:
		RETVAL