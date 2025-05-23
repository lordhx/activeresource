# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"
require "fixtures/customer"
require "fixtures/street_address"
require "fixtures/beast"
require "fixtures/proxy"
require "fixtures/pet"
require "active_support/core_ext/hash/conversions"

class FinderTest < ActiveSupport::TestCase
  def setup
    setup_response # find me in abstract_unit
  end

  def test_find_by_id
    matz = Person.find(1)
    assert_kind_of Person, matz
    assert_equal "Matz", matz.name
    assert matz.name?
  end

  def test_find_by_id_with_custom_prefix
    addy = StreetAddress.find(1, params: { person_id: 1 })
    assert_kind_of StreetAddress, addy
    assert_equal "12345 Street", addy.street
  end

  def test_find_all
    all = Person.find(:all)
    assert_equal 2, all.size
    assert_kind_of Person, all.first
    assert_equal "Matz", all.first.name
    assert_equal "David", all.last.name
  end

  def test_all
    all = Person.all
    assert_equal 2, all.size
    assert_kind_of Person, all.first
    assert_equal "Matz", all.first.name
    assert_equal "David", all.last.name
  end

  def test_all_with_params
    all = StreetAddress.all(params: { person_id: 1 })
    assert_equal 1, all.size
    assert_kind_of StreetAddress, all.first
  end

  def test_where
    people = Person.where
    assert_equal 2, people.size
    assert_kind_of Person, people.first
    assert_equal "Matz", people.first.name
    assert_equal "David", people.last.name
  end

  def test_where_with_clauses
    addresses = StreetAddress.where(person_id: 1)
    assert_equal 1, addresses.size
    assert_kind_of StreetAddress, addresses.first
  end

  def test_where_with_multiple_where_clauses
    ActiveResource::HttpMock.respond_to.get "/people.json?id=2&name=david", {}, @people_david

    people = Person.where(id: 2).where(name: "david")
    assert_equal 1, people.size
    assert_kind_of Person, people.first
    assert_equal 2, people.first.id
    assert_equal "David", people.first.name
  end

  def test_where_chained_from_all
    ActiveResource::HttpMock.respond_to.get "/records.json?id=2", {}, @people_david

    people = Person.all(from: "/records.json").where(id: 2)
    assert_equal 1, people.size
    assert_kind_of Person, people.first
    assert_equal 2, people.first.id
    assert_equal "David", people.first.name
  end

  def test_where_with_chained_into_all
    ActiveResource::HttpMock.respond_to.get "/records.json?id=2&name=david", {}, @people_david

    people = Person.where(id: 2).all(from: "/records.json", params: { name: "david" })
    assert_equal 1, people.size
    assert_kind_of Person, people.first
    assert_equal 2, people.first.id
    assert_equal "David", people.first.name
  end

  def test_where_loading
    ActiveResource::HttpMock.respond_to.get "/people.json?id=2", {}, @people_david
    people = Person.where(id: 2)

    assert_changes -> { ActiveResource::HttpMock.requests.count }, from: 0, to: 1 do
      people.load
    end
    assert_no_changes -> { ActiveResource::HttpMock.requests.count }, from: 1 do
      10.times { people.load }
    end
  end

  def test_where_reloading
    ActiveResource::HttpMock.respond_to.get "/people.json?id=2", {}, @people_david
    people = Person.where(id: 2)

    assert_changes -> { ActiveResource::HttpMock.requests.count }, from: 0, to: 1 do
      assert_equal 1, people.size
    end
    assert_no_changes -> { ActiveResource::HttpMock.requests.count }, from: 1 do
      assert_equal 1, people.size
    end
    assert_changes -> { ActiveResource::HttpMock.requests.count }, from: 1, to: 2 do
      people.reload
    end
    assert_no_changes -> { ActiveResource::HttpMock.requests.count }, from: 2 do
      assert_equal 1, people.size
    end
  end

  def test_where_with_clause_in
    ActiveResource::HttpMock.respond_to { |m| m.get "/people.json?id%5B%5D=2", {}, @people_david }
    people = Person.where(id: [2])
    assert_equal 1, people.size
    assert_kind_of Person, people.first
    assert_equal "David", people.first.name
  end

  def test_where_with_invalid_clauses
    error = assert_raise(ArgumentError) { Person.where(nil) }
    assert_equal "expected a clauses Hash, got nil", error.message
  end

  def test_find_first
    matz = Person.find(:first)
    assert_kind_of Person, matz
    assert_equal "Matz", matz.name
  end

  def test_first
    matz = Person.first
    assert_kind_of Person, matz
    assert_equal "Matz", matz.name
  end

  def test_first_with_params
    addy = StreetAddress.first(params: { person_id: 1 })
    assert_kind_of StreetAddress, addy
    assert_equal "12345 Street", addy.street
  end

  def test_find_last
    david = Person.find(:last)
    assert_kind_of Person, david
    assert_equal "David", david.name
  end

  def test_last
    david = Person.last
    assert_kind_of Person, david
    assert_equal "David", david.name
  end

  def test_last_with_params
    addy = StreetAddress.last(params: { person_id: 1 })
    assert_kind_of StreetAddress, addy
    assert_equal "12345 Street", addy.street
  end

  def test_find_by_id_not_found
    assert_raise(ActiveResource::ResourceNotFound) { Person.find(99) }
    assert_raise(ActiveResource::ResourceNotFound) { StreetAddress.find(99, params: { person_id: 1 }) }
  end

  def test_find_all_sub_objects
    all = StreetAddress.find(:all, params: { person_id: 1 })
    assert_equal 1, all.size
    assert_kind_of StreetAddress, all.first
    assert_equal ({ person_id: 1 }), all.first.prefix_options
  end

  def test_find_all_sub_objects_not_found
    assert_nothing_raised do
      StreetAddress.find(:all, params: { person_id: 2 })
    end
  end

  def test_find_all_by_from
    ActiveResource::HttpMock.respond_to { |m| m.get "/companies/1/people.json", {}, @people_david }

    people = Person.find(:all, from: "/companies/1/people.json")
    assert_equal 1, people.size
    assert_equal "David", people.first.name
  end

  def test_find_all_by_from_with_options
    ActiveResource::HttpMock.respond_to { |m| m.get "/companies/1/people.json", {}, @people_david }

    people = Person.find(:all, from: "/companies/1/people.json")
    assert_equal 1, people.size
    assert_equal "David", people.first.name
  end

  def test_find_all_by_from_with_prefix
    ActiveResource::HttpMock.respond_to { |m| m.get "/dogs.json", {}, @pets }

    pets = Pet.find(:all, from: "/dogs.json", params: { person_id: 1 })
    assert_equal 2, pets.size
    assert_equal "Max", pets.first.name
    assert_equal ({ person_id: 1 }), pets.first.prefix_options

    assert_equal "Daisy", pets.second.name
    assert_equal ({ person_id: 1 }), pets.second.prefix_options
  end

  def test_find_all_by_symbol_from
    ActiveResource::HttpMock.respond_to { |m| m.get "/people/managers.json", {}, @people_david }

    people = Person.find(:all, from: :managers)
    assert_equal 1, people.size
    assert_equal "David", people.first.name
  end

  def test_find_all_by_symbol_from_with_prefix
    ActiveResource::HttpMock.respond_to { |m| m.get "/people/1/pets/dogs.json", {}, @pets }

    pets = Pet.find(:all, from: :dogs, params: { person_id: 1 })
    assert_equal 2, pets.size
    assert_equal "Max", pets.first.name
    assert_equal ({ person_id: 1 }), pets.first.prefix_options

    assert_equal "Daisy", pets.second.name
    assert_equal ({ person_id: 1 }), pets.second.prefix_options
  end

  def test_find_first_or_last_not_found
    ActiveResource::HttpMock.respond_to { |m| m.get "/people.json", {}, "", 404 }

    assert_nothing_raised { Person.find(:first) }
    assert_nothing_raised { Person.find(:last)  }
  end

  def test_find_single_by_from
    ActiveResource::HttpMock.respond_to { |m| m.get "/companies/1/manager.json", {}, @david }

    david = Person.find(:one, from: "/companies/1/manager.json")
    assert_equal "David", david.name
  end

  def test_find_single_by_symbol_from
    ActiveResource::HttpMock.respond_to { |m| m.get "/people/leader.json", {}, @david }

    david = Person.find(:one, from: :leader)
    assert_equal "David", david.name
  end

  def test_find_identifier_encoding
    ActiveResource::HttpMock.respond_to { |m| m.get "/people/%3F.json", {}, @david }

    david = Person.find("?")

    assert_equal "David", david.name
  end

  def test_find_identifier_encoding_for_path_traversal
    ActiveResource::HttpMock.respond_to { |m| m.get "/people/..%2F.json", {}, @david }

    david = Person.find("../")

    assert_equal "David", david.name
  end
end
