<?php

namespace Drupal\devconnect_user;

class DeveloperEntity {
  /**
   * @var array
   */
  public $apps;
  /**
   * @var string
   * This is actually the unique-key (within the org) for the Developer
   */
  public $email;
  /**
   * @var string
   * Read-only alternate unique ID. Useful when querying developer analytics.
   */
  public $developerId;
  /**
   * @var string
   */
  public $firstName;
  /**
   * @var string
   */
  public $lastName;
  /**
   * @var string
   */
  public $userName;
  /**
   * @var string
   * Read-only
   */
  public $organizationName;
  /**
   * @var string
   * Should be either 'active' or 'inactive'.
   */
  public $status;
  /**
   * @var array
   */
  public $attributes;
  /**
   * @var int
   * Read-only
   */
  public $createdAt;
  /**
   * @var string
   * Read-only
   */
  public $createdBy;
  /**
   * @var int
   * Read-only
   */
  public $modifiedAt;
  /**
   * @var string
   * Read-only
   */
  public $modifiedBy;
  /**
   * @var int
   * Read-only
   */
  public $uid;
  /**
   * @var array
   */
  public $debugData;
  /**
   * @var array
   */
  public $orgNames;
  /**
   * @var array
   */
  public $companies;
  /**
   * @var boolean
   */
  public $forceSync = FALSE;

  public function __construct(array $values = array()) {
    $this->orgNames = array();
    $this->companies = array();
    // Populate values if available.
    if (is_array($values)) {
      foreach ($values as $key => $value) {
        if (property_exists($this, $key)) {
          $this->$key = $value;
        }
      }
    }
  }

  public function toArray() {
    $properties = get_object_vars($this);
    unset($properties['debugData']);
    return $properties;
  }

  public function getAttribute($name) {
    if (!is_array($this->attributes) || !array_key_exists($name, $this->attributes)) {
      return NULL;
    }
    return $this->attributes[$name];
  }
}
