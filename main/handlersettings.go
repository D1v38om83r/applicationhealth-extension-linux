package main

import (
	"encoding/json"

	"github.com/Azure/azure-docker-extension/pkg/vmextension"
	"github.com/go-kit/kit/log"
	"github.com/pkg/errors"
)

var (
	errTcpMustNotIncludeRequestPath    = errors.New("'requestPath' cannot be specified when using 'tcp' protocol")
	errTcpConfigurationMustIncludePort = errors.New("'port' must be specified when using 'tcp' protocol")
	errProbeSettleTimeExceedsThreshold = errors.New("Probe settle time (intervalInSeconds * numberOfProbes) cannot exceed 120 seconds")
	defaultIntervalInSeconds           = 5
	defaultNumberOfProbes              = 1
	maximumProbeSettleTime             = 120
)

// handlerSettings holds the configuration of the extension handler.
type handlerSettings struct {
	publicSettings
	protectedSettings
}

func (s *handlerSettings) protocol() string {
	return s.publicSettings.Protocol
}

func (s *handlerSettings) requestPath() string {
	return s.publicSettings.RequestPath
}

func (s *handlerSettings) port() int {
	return s.publicSettings.Port
}

func (s *handlerSettings) intervalInSeconds() int {
	var intervalInSeconds = s.publicSettings.IntervalInSeconds
	if intervalInSeconds == 0 {
		return defaultIntervalInSeconds
	} else {
		return intervalInSeconds
	}
}

func (s *handlerSettings) numberOfProbes() int {
	var numberOfProbes = s.publicSettings.NumberOfProbes
	if numberOfProbes == 0 {
		return defaultNumberOfProbes
	} else {
		return numberOfProbes
	}
}

func (s *handlerSettings) gracePeriod() int {
	var gracePeriod = s.publicSettings.GracePeriod
	if gracePeriod == 0 {
		return s.intervalInSeconds() * s.numberOfProbes()
	} else {
		return gracePeriod
	}
}

// validate makes logical validation on the handlerSettings which already passed
// the schema validation.
func (h handlerSettings) validate() error {
	if h.protocol() == "tcp" && h.port() == 0 {
		return errTcpConfigurationMustIncludePort
	}

	if h.protocol() == "tcp" && h.requestPath() != "" {
		return errTcpMustNotIncludeRequestPath
	}

	probeSettlingTime := h.intervalInSeconds() * h.numberOfProbes()
	if probeSettlingTime > maximumProbeSettleTime {
		return errProbeSettleTimeExceedsThreshold
	}

	return nil
}

// publicSettings is the type deserialized from public configuration section of
// the extension handler. This should be in sync with publicSettingsSchema.
type publicSettings struct {
	Protocol          string `json:"protocol"`
	Port              int    `json:"port,int"`
	RequestPath       string `json:"requestPath"`
	IntervalInSeconds int    `json:"intervalInSeconds,int"`
	NumberOfProbes    int    `json:"numberOfProbes,int"`
	GracePeriod       int    `json:"gracePeriod,int"`
}

// protectedSettings is the type decoded and deserialized from protected
// configuration section. This should be in sync with protectedSettingsSchema.
type protectedSettings struct {
}

// parseAndValidateSettings reads configuration from configFolder, decrypts it,
// runs JSON-schema and logical validation on it and returns it back.
func parseAndValidateSettings(ctx *log.Context, configFolder string) (h handlerSettings, _ error) {
	ctx.Log("event", "reading configuration")
	pubJSON, protJSON, err := readSettings(configFolder)
	if err != nil {
		return h, err
	}
	ctx.Log("event", "read configuration")

	ctx.Log("event", "validating json schema")
	if err := validateSettingsSchema(pubJSON, protJSON); err != nil {
		return h, errors.Wrap(err, "json validation error")
	}
	ctx.Log("event", "json schema valid")

	ctx.Log("event", "parsing configuration json")
	if err := vmextension.UnmarshalHandlerSettings(pubJSON, protJSON, &h.publicSettings, &h.protectedSettings); err != nil {
		return h, errors.Wrap(err, "json parsing error")
	}
	ctx.Log("event", "parsed configuration json")

	ctx.Log("event", "validating configuration logically")
	if err := h.validate(); err != nil {
		return h, errors.Wrap(err, "invalid configuration")
	}
	ctx.Log("event", "validated configuration")
	return h, nil
}

// readSettings uses specified configFolder (comes from HandlerEnvironment) to
// decrypt and parse the public/protected settings of the extension handler into
// JSON objects.
func readSettings(configFolder string) (pubSettingsJSON, protSettingsJSON map[string]interface{}, err error) {
	pubSettingsJSON, protSettingsJSON, err = vmextension.ReadSettings(configFolder)
	err = errors.Wrapf(err, "error reading extension configuration")
	return
}

// validateSettings takes publicSettings and protectedSettings as JSON objects
// and runs JSON schema validation on them.
func validateSettingsSchema(pubSettingsJSON, protSettingsJSON map[string]interface{}) error {
	pubJSON, err := toJSON(pubSettingsJSON)
	if err != nil {
		return errors.Wrap(err, "failed to unmarshal public settings into json")
	}
	protJSON, err := toJSON(protSettingsJSON)
	if err != nil {
		return errors.Wrap(err, "failed to unmarshal protected settings into json")
	}

	if err := validatePublicSettings(pubJSON); err != nil {
		return err
	}
	if err := validateProtectedSettings(protJSON); err != nil {
		return err
	}
	return nil
}

// toJSON converts given in-memory JSON object representation into a JSON object string.
func toJSON(o map[string]interface{}) (string, error) {
	if o == nil { // instead of JSON 'null' assume empty object '{}'
		return "{}", nil
	}
	b, err := json.Marshal(o)
	return string(b), errors.Wrap(err, "failed to marshal into json")
}
