%{
/*
    lib/calib_yacc.y
    code for parsing calibration file, generated by bison

    Copyright (C) 2003 Frank Mori Hess <fmhess@users.sourceforge.net>

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation, version 2.1
    of the License.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307
    USA.
*/

#define _GNU_SOURCE

#include <stdio.h>
#include "libinternal.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include "calib_yacc.h"
#include "calib_lex.h"

#define YYERROR_VERBOSE
#define YYPARSE_PARAM parse_arg
#define YYLEX_PARAM priv(YYPARSE_PARAM)->yyscanner

enum polynomial_direction
{
	POLYNOMIAL_TO_PHYS,
	POLYNOMIAL_FROM_PHYS
};

typedef struct
{
	yyscan_t yyscanner;
	comedi_calibration_t *parsed_file;
	comedi_caldac_t caldac;
	int cal_index;
	unsigned num_coefficients;
	comedi_polynomial_t polynomial;
} calib_yyparse_private_t;

YY_DECL;

static inline calib_yyparse_private_t* priv( calib_yyparse_private_t *parse_arg)
{
	return parse_arg;
}

static void free_calibration_setting( comedi_calibration_setting_t *setting )
{
	if( setting->channels );
	{
		free( setting->channels );
		setting->channels = NULL;
		setting->num_channels = 0;
	}
	if( setting->ranges );
	{
		free( setting->ranges );
		setting->ranges = NULL;
		setting->num_ranges = 0;
	}
	setting->num_arefs = 0;
	if( setting->caldacs );
	{
		free( setting->caldacs );
		setting->caldacs = NULL;
		setting->num_caldacs = 0;
	}
	if(setting->soft_calibration.to_phys)
	{
		free(setting->soft_calibration.to_phys);
		setting->soft_calibration.to_phys = NULL;
	}
	if(setting->soft_calibration.from_phys)
	{
		free(setting->soft_calibration.from_phys);
		setting->soft_calibration.from_phys = NULL;
	}
}

static void free_settings( comedi_calibration_t *file_contents )
{
	int i;

	if( file_contents->settings == NULL ) return;

	for( i = 0; i < file_contents->num_settings; i++ )
	{
		free_calibration_setting( &file_contents->settings[ i ] );
	}
	file_contents->settings = NULL;
}

static int add_calibration_setting( comedi_calibration_t *file_contents )
{
	comedi_calibration_setting_t *temp;

	temp = realloc( file_contents->settings,
		( file_contents->num_settings + 1 ) * sizeof( comedi_calibration_setting_t ) );
	if( temp == NULL )
	{
		fprintf(stderr, "%s: realloc failed to allocate memory.\n", __FUNCTION__);
		return -1;
	}
	file_contents->settings = temp;
	memset( &file_contents->settings[ file_contents->num_settings ],
		0, sizeof( comedi_calibration_setting_t ) );

	file_contents->num_settings++;
	return 0;
}

static comedi_calibration_setting_t* current_setting( calib_yyparse_private_t *priv )
{
	int retval;

	while( priv->cal_index >= priv->parsed_file->num_settings )
	{
		retval = add_calibration_setting( priv->parsed_file );
		if( retval < 0 ) return NULL;
	}
	return &priv->parsed_file->settings[ priv->cal_index ];
}

static int add_channel( calib_yyparse_private_t *priv, int channel )
{
	int *temp;
	comedi_calibration_setting_t *setting;

	setting = current_setting( priv );
	if( setting == NULL ) return -1;

	temp = realloc( setting->channels, ( setting->num_channels + 1 ) * sizeof( int ) );
	if( temp == NULL )
	{
		fprintf(stderr, "%s: realloc failed to allocate memory.\n", __FUNCTION__);
		return -1;
	}
	setting->channels = temp;
	setting->channels[ setting->num_channels++ ] = channel;
	return 0;
}

static int add_range( calib_yyparse_private_t *priv, int range )
{
	int *temp;
	comedi_calibration_setting_t *setting;

	setting = current_setting( priv );
	if( setting == NULL ) return -1;

	temp = realloc( setting->ranges, ( setting->num_ranges + 1 ) * sizeof( int ) );
	if( temp == NULL )
	{
		fprintf(stderr, "%s: realloc failed to allocate memory.\n", __FUNCTION__);
		return -1;
	}
	setting->ranges = temp;
	setting->ranges[ setting->num_ranges++ ] = range;
	return 0;
}

static int add_aref( calib_yyparse_private_t *priv, int aref )
{
	comedi_calibration_setting_t *setting;

	setting = current_setting( priv );
	if( setting == NULL ) return -1;

	if( setting->num_arefs >= sizeof( setting->arefs ) /
		sizeof( setting->arefs[ 0 ] ) )
		return -1;
	setting->arefs[ setting->num_arefs++ ] = aref;
	return 0;
}

static int add_caldac( calib_yyparse_private_t *priv,
	comedi_caldac_t caldac )
{
	comedi_caldac_t *temp;
	comedi_calibration_setting_t *setting;

	setting = current_setting( priv );
	if( setting == NULL ) return -1;

	temp = realloc( setting->caldacs, ( setting->num_caldacs + 1 ) *
		sizeof( comedi_caldac_t ) );
	if( temp == NULL )
	{
		fprintf(stderr, "%s: realloc failed to allocate memory.\n", __FUNCTION__);
		return -1;
	}
	setting->caldacs = temp;
	setting->caldacs[ setting->num_caldacs++ ] = caldac;
	return 0;
}

static int add_polynomial(calib_yyparse_private_t *priv, enum polynomial_direction polynomial_direction)
{
	comedi_calibration_setting_t *setting;

	setting = current_setting( priv );
	if( setting == NULL )
	{
		fprintf(stderr, "%s: current_setting returned NULL\n", __FUNCTION__);
		return -1;
	}
	if(priv->num_coefficients < 1)
	{
		fprintf(stderr, "%s: polynomial has no coefficients.\n", __FUNCTION__);
		return -1;
	}
	if(polynomial_direction == POLYNOMIAL_TO_PHYS)
	{
		if(setting->soft_calibration.to_phys) return -1;
		setting->soft_calibration.to_phys = malloc(sizeof(comedi_polynomial_t));
		*setting->soft_calibration.to_phys = priv->polynomial;
	}else
	{
		if(setting->soft_calibration.from_phys) return -1;
		setting->soft_calibration.from_phys = malloc(sizeof(comedi_polynomial_t));
		*setting->soft_calibration.from_phys = priv->polynomial;
	}
	return 0;
}

static int add_polynomial_coefficient(calib_yyparse_private_t *priv, double coefficient)
{
	if(priv->num_coefficients >= COMEDI_MAX_NUM_POLYNOMIAL_COEFFICIENTS)
	{
		fprintf(stderr, "too many coefficients for polynomial,\n");
		fprintf(stderr, "num_coefficients=%i, max is %i .\n", priv->num_coefficients, COMEDI_MAX_NUM_POLYNOMIAL_COEFFICIENTS);
		return -1;
	}
	priv->polynomial.order = priv->num_coefficients;
	priv->polynomial.coefficients[priv->num_coefficients++] = coefficient;
	return 0;
}

static comedi_calibration_t* alloc_calib_parse( void )
{
	comedi_calibration_t *file_contents;

	file_contents = malloc( sizeof( *file_contents ) );
	if( file_contents == NULL ) return file_contents;
	memset( file_contents, 0, sizeof( *file_contents ) );
	return file_contents;
}

EXPORT_ALIAS_DEFAULT(_comedi_cleanup_calibration,comedi_cleanup_calibration,0.7.20);
extern void _comedi_cleanup_calibration( comedi_calibration_t *file_contents )
{
	if( file_contents->driver_name )
	{
		free( file_contents->driver_name );
		file_contents->driver_name = NULL;
	}
	if( file_contents->board_name )
	{
		free( file_contents->board_name );
		file_contents->board_name = NULL;
	}
	free_settings( file_contents );
	free( file_contents );
}

static comedi_polynomial_t* alloc_inverse_linear_polynomial(const comedi_polynomial_t *polynomial)
{
	if(polynomial->order != 1) return NULL;
	comedi_polynomial_t *inverse = malloc(sizeof(comedi_polynomial_t));
	memset(inverse, 0, sizeof(comedi_polynomial_t));
	inverse->order = 1;
	inverse->expansion_origin = polynomial->coefficients[0];
	inverse->coefficients[0] = polynomial->expansion_origin;
	inverse->coefficients[1] = 1. / polynomial->coefficients[1];
	if(isfinite(inverse->coefficients[1]) == 0)
	{
		free(inverse);
		return NULL;
	}
	return inverse;
}

static void fill_inverse_linear_polynomials(comedi_calibration_t *calibration)
{
	unsigned i;
	for(i = 0; i < calibration->num_settings; ++i)
	{
		if(calibration->settings[i].soft_calibration.to_phys)
		{
			if(calibration->settings[i].soft_calibration.from_phys == NULL)
			{
				calibration->settings[i].soft_calibration.from_phys =
					alloc_inverse_linear_polynomial(calibration->settings[i].soft_calibration.to_phys);
			}
		}else if(calibration->settings[i].soft_calibration.from_phys)
		{
			calibration->settings[i].soft_calibration.to_phys =
				alloc_inverse_linear_polynomial(calibration->settings[i].soft_calibration.from_phys);
		}
	}
}

EXPORT_ALIAS_DEFAULT(_comedi_parse_calibration_file,comedi_parse_calibration_file,0.7.20);
extern comedi_calibration_t* _comedi_parse_calibration_file( const char *cal_file_path )
{
	calib_yyparse_private_t priv;
	FILE *file;

	if( cal_file_path == NULL ) return NULL;
	memset(&priv, 0, sizeof(calib_yyparse_private_t));
	priv.parsed_file = alloc_calib_parse();
	if( priv.parsed_file == NULL ) return NULL;

	file = fopen( cal_file_path, "r" );
	if( file == NULL )
	{
		COMEDILIB_DEBUG( 3, "failed to open file\n" );
		return NULL;
	}
	calib_yylex_init(&priv.yyscanner);
	calib_yyrestart(file, priv.yyscanner);
	if( calib_yyparse( &priv ) )
	{
		comedi_cleanup_calibration( priv.parsed_file );
		priv.parsed_file = NULL;
	}
	calib_yylex_destroy(priv.yyscanner);
	fclose( file );
	fill_inverse_linear_polynomials(priv.parsed_file);
	return priv.parsed_file;
}

%}

%pure_parser

%union
{
	int  ival;
	double dval;
	char *sval;
}

%token T_DRIVER_NAME T_BOARD_NAME T_CALIBRATIONS T_SUBDEVICE T_CHANNELS
%token T_RANGES T_AREFS T_CALDACS T_CHANNEL T_VALUE T_NUMBER T_STRING
%token T_COEFFICIENTS T_EXPANSION_ORIGIN T_SOFTCAL_TO_PHYS T_SOFTCAL_FROM_PHYS
%token T_ASSIGN T_FLOAT

%type <ival> T_NUMBER
%type <sval> T_STRING
%type <dval> T_FLOAT

%%

	input: '{' hash '}'
		| error
			{
				fprintf(stderr, "input error on line %i\n", calib_yyget_lineno(priv(parse_arg)->yyscanner));
// 				fprintf(stderr, "input error on line %i\n", @1.first_line );
				YYABORT;
			}
		;

	hash: /* empty */
		| hash_element
		| hash_element ',' hash
		;

	hash_element: T_DRIVER_NAME T_ASSIGN T_STRING
		{
			if( priv(parse_arg)->parsed_file->driver_name != NULL ) YYABORT;
			priv(parse_arg)->parsed_file->driver_name = strdup( $3 );
		}
		| T_BOARD_NAME T_ASSIGN T_STRING
		{
			if( priv(parse_arg)->parsed_file->board_name != NULL ) YYABORT;
			priv(parse_arg)->parsed_file->board_name = strdup( $3 );
		}
		| T_CALIBRATIONS T_ASSIGN '[' calibrations_array ']'
		;

	calibrations_array: /* empty */
		| '{' calibration_setting '}'
		| '{' calibration_setting '}' ',' calibrations_array
		;

	calibration_setting: /* empty */ { priv(parse_arg)->cal_index++; }
		| calibration_setting_element { priv(parse_arg)->cal_index++; }
		| calibration_setting_element ',' calibration_setting
		;

	calibration_setting_element: T_SUBDEVICE T_ASSIGN T_NUMBER
		{
			comedi_calibration_setting_t *setting;
			setting = current_setting( parse_arg );
			if( setting == NULL ) YYABORT;
			setting->subdevice = $3;
		}
		| T_CHANNELS T_ASSIGN '[' channels_array ']'
		| T_RANGES T_ASSIGN '[' ranges_array ']'
		| T_AREFS T_ASSIGN '[' arefs_array ']'
		| T_CALDACS T_ASSIGN '[' caldacs_array ']'
		| T_SOFTCAL_TO_PHYS T_ASSIGN '{' polynomial '}'
		{
			if(add_polynomial(parse_arg, POLYNOMIAL_TO_PHYS) < 0) YYERROR;
			priv(parse_arg)->num_coefficients = 0;
		}
		| T_SOFTCAL_FROM_PHYS T_ASSIGN '{' polynomial '}'
		{
			if(add_polynomial(parse_arg, POLYNOMIAL_FROM_PHYS) < 0) YYERROR;
			priv(parse_arg)->num_coefficients = 0;
		}
		;

	channels_array: /* empty */
		| channel
		| channel ',' channels_array
		;

	channel: T_NUMBER { if(add_channel( parse_arg, $1 ) < 0) YYERROR; }
		;

	ranges_array: /* empty */
		| range
		| range ',' ranges_array
		;

	range: T_NUMBER { if(add_range( parse_arg, $1 ) < 0) YYERROR; }
		;

	arefs_array: /* empty */
		| aref
		| aref ',' arefs_array
		;

	aref: T_NUMBER { if(add_aref( parse_arg, $1 ) < 0) YYERROR; }
		;

	caldacs_array: /* empty */
		| '{' caldac '}'
		| '{' caldac '}' ',' caldacs_array
		;

	caldac: /* empty */ { if(add_caldac( parse_arg, priv(parse_arg)->caldac ) < 0) YYERROR; }
		| caldac_element { if(add_caldac( parse_arg, priv(parse_arg)->caldac ) < 0) YYERROR; }
		| caldac_element ',' caldac
		;

	caldac_element: T_SUBDEVICE T_ASSIGN T_NUMBER { priv(parse_arg)->caldac.subdevice = $3; }
		| T_CHANNEL T_ASSIGN T_NUMBER { priv(parse_arg)->caldac.channel = $3; }
		| T_VALUE T_ASSIGN T_NUMBER { priv(parse_arg)->caldac.value = $3; }
		;

	polynomial: /* empty */
		| polynomial_element
		| polynomial_element ',' polynomial
		;

	polynomial_element: T_COEFFICIENTS T_ASSIGN '[' coefficient_array ']'
		| T_EXPANSION_ORIGIN T_ASSIGN expansion_origin
		;

	coefficient_array: /* empty */
		| coefficient
		| coefficient ',' coefficient_array
		;

	coefficient: T_FLOAT
		{
			if(add_polynomial_coefficient(parse_arg, $1) < 0) YYERROR;
		}
		| T_NUMBER
		{
			if(add_polynomial_coefficient(parse_arg, $1) < 0) YYERROR;
		}
		;

	expansion_origin: T_FLOAT
		{
			priv(parse_arg)->polynomial.expansion_origin = $1;
		}
		| T_NUMBER
		{
			priv(parse_arg)->polynomial.expansion_origin = $1;
		}
		;

%%

void calib_yyerror(char *s)
{
	fprintf(stderr, "%s\n", s);
}



