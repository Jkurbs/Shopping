//
//  DataService.swift
//  Lidora
//
//  Created by Kerby Jean on 9/9/20.
//


import Stripe
import FirebaseAuth
import FirebaseFirestore



class DataService {
    
    static let shared = DataService()
    
    // MARK: - Firebase Refs
    
    var RefChefs: CollectionReference {
        return Firestore.firestore().collection("chefs")
    }
    
    var CurrentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    var RefCurrentUser: DocumentReference {
        return Firestore.firestore().collection("customers").document(CurrentUserId ?? "")
    }
    
    var RefPaymentsMethods: CollectionReference {
        return RefCurrentUser.collection("payment_methods")
    }
    
    var RefOrders: CollectionReference {
        return RefCurrentUser.collection("orders")
    }

    // MARK: - Functions
    
    // SAVE USER DETAILS
    func saveUserDetails(userId: String, data: [String: Any], complete: @escaping (Bool, Error?) -> Void) {
        self.RefCurrentUser.setData(data, merge: true) { (error) in
            if let error = error {
                print("Error saving user details: ", error)
                complete(false, error)
            } else {
                complete(true, nil)
            }
        }
    }
    
    // UPDATE USER LOCATION
    func updateUserLocation(line1: String, postalCode: String, state: String) {
        
    }
    
    // FETCH CURRENT USER
    func fetchUser(userId: String, complete: @escaping (User?, Error?) -> Void) {
        self.RefCurrentUser.getDocument { (snapshot, error) in
            if let error = error {
                print("Error fetch user details: ", error)
                complete(nil, error)
            } else {
                guard let snapshot = snapshot, let data = snapshot.data() else { return }
                let id = snapshot.documentID
                let user = User(id: id, data: data)
                complete(user, nil)
            }
        }
    }
    
    
    // CREATE STRIPE PAYMENT METHOD
    func createStripePaymentMethod(primaryCard: String, cardNumber: String, month: UInt, year: UInt, cvc: String, complete: @escaping (Bool, Error?) -> Void) {
        
        let cardParams = STPCardParams()
        cardParams.number = cardNumber
        cardParams.expMonth =  month
        cardParams.expYear = year
        cardParams.cvc = cvc
        
        let params = STPPaymentMethodCardParams(cardSourceParams: cardParams)
        let paymentMethodParams = STPPaymentMethodParams(card: params, billingDetails: nil, metadata: nil)
        
        STPAPIClient.shared().createPaymentMethod(with: paymentMethodParams) { (method, error) in
            if let error = error {
                complete(false, error)
            } else {
                self.addPaymentMethod(primaryCard: primaryCard, tokenId: method!.stripeId, number: cardNumber, cvc: cvc) { (success, error) in
                    if let error = error {
                        complete(false, error)
                    } else {
                        complete(true, nil)
                    }
                }
            }
        }
    }
    
    
    // ADD PAYMENT METHOD
    func addPaymentMethod(primaryCard: String, tokenId: String, number: String, cvc: String, complete: @escaping (Bool, Error?) -> Void) {
        RefPaymentsMethods.document(tokenId).setData(["id": tokenId, "number": number, "cvc": cvc], merge: true) { (error) in
            if let error = error {
                complete(false, error)
            } else {
                self.RefPaymentsMethods.document(primaryCard).updateData(["primary": false]) { (error) in
                    if let error = error {
                        complete(false, error)
                    } else {
                        complete(true, nil)
                    }
                }
            }
        }
    }
    
    
    // FETCH PRIMARY PAYMENT METHOD
    func fetchPrimaryPaymentMethod(cardId: String, complete: @escaping (Card?, Error?) -> Void) {
        RefPaymentsMethods.document(cardId).getDocument(completion: { (snapshot, error) in
            if let error = error {
                complete(nil, error)
            } else {
                guard let snapshot = snapshot, let data = snapshot.data() else { return }
                    if snapshot.exists {
                        let id = snapshot.documentID
                        let card = Card(id: id, data: data)
                        complete(card, error)
                }
            }
        })
    }
    
    
    // SET PRIMARY PAYMENT METHOD
    func setPrimaryPaymentMethod(oldCardId: String, cardId: String) {
        RefPaymentsMethods.document(oldCardId).updateData(["primary": false])
        RefPaymentsMethods.document(cardId).setData(["primary": true], merge: true)
    }
    
    
    // FETCH PAYMENT METHODS
    func fetchPaymentMethods(complete: @escaping (Card?, Error?) -> Void) {
        RefPaymentsMethods.getDocuments { (snapshot, error) in
            if let error = error {
                complete(nil, error)
            } else {
                for document in snapshot!.documents {
                    if document.exists {
                        let id = document.documentID
                        let data = document.data()
                        let card = Card(id: id, data: data)
                        complete(card, error)
                    }
                }
            }
        }
    }
    
    
    // REMOVE PAYMENT METHOD
    func removePaymentMethod(id: String, complete: @escaping (Bool, Error?) -> Void) {
        RefPaymentsMethods.document(id).delete { (error) in
            if let error = error {
                complete(false, error)
            } else {
                complete(true, nil)
            }
        }
    }
    
    
    // FETCH CHEFS
    func fetchChefs(id: String, complete: @escaping (Chef?, Error?) -> Void) {
        self.RefChefs.getDocuments(completion: { (snapshot, error) in
            if let error = error {
                complete(nil, error)
            } else {
                
                for document in snapshot!.documents {
                    let id = document.documentID
                    let data = document.data()
                    let chef = Chef(key: id, data: data)
                    complete(chef, nil)
                }
            }
        })
    }
    
    // FETCH SELECTED CHEF MENU
    func fetchMenu(id: String, complete: @escaping (Menu?, Error?) -> Void) {
        self.RefChefs.document(id).collection("menu").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching menu: ", error)
                complete(nil, error)
            } else {
                for document in snapshot!.documents {
                    let id = document.documentID
                    let data = document.data()
                    let menu = Menu(key: id, data: data)
                    complete(menu, nil)
                }
            }
        }
    }
    
    // ADD ITEM TO ORDER
    func addItemToOrder(orderId: String, chef: Chef, item: Menu, quantity: Int, total: Double, complete: @escaping (Bool?, Error?) -> Void) {
        guard let providerId = chef.id, let name = item.name, let description = item.description, let imageURL = item.imageURL else { return }
        let ref = self.RefCurrentUser.collection("orders").document(orderId)
        let itemRef = ref.collection("items").document(item.id)
        Firestore.firestore().runTransaction({ (transaction, errorPointer) -> Any? in
            let document: DocumentSnapshot
            let itemDocument: DocumentSnapshot
            do {
                try document = transaction.getDocument(ref)
                try itemDocument = transaction.getDocument(itemRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                complete(false, fetchError)
                return nil
            }

            if document.exists {
                guard let totalPrice = document.data()?["total"] as? Double, let totalQuantity = document.data()?["quantity"] as? Int else {
                    return nil
                }
                let service = (total + totalPrice).serviceFee()
                let subtotal = service.subtotal
                let platformFee = service.platformFee
                let stripeFee = service.stripeFee
                let serviceFee = service.serviceFee
                let total = service.total

                transaction.updateData(["subtotal": subtotal, "platform_fee": platformFee, "stripe_fee": stripeFee, "service_fee": serviceFee, "total": total, "quantity":  quantity + totalQuantity], forDocument: ref)
            } else {
                let service = total.serviceFee()
                let subtotal = service.subtotal
                let platformFee = service.platformFee
                let stripeFee = service.stripeFee
                let serviceFee = service.serviceFee
                let total = service.total
                
                transaction.setData(["subtotal": subtotal, "platform_fee": platformFee, "stripe_fee": stripeFee, "service_fee": serviceFee, "total": total, "quantity":  quantity, "provider_id": chef.id!, "provider_name": chef.firstName!], forDocument: ref)
            }
            
            if itemDocument.exists {
                guard let totalPrice = itemDocument.data()?["total"] as? Double, let totalQuantity = itemDocument.data()?["quantity"] as? Int else {
                    return nil
                }
                
                let roundedTotal = roundNumber(total + totalPrice)
                transaction.updateData(["total": roundedTotal, "quantity":  quantity + totalQuantity], forDocument: itemRef)
            } else {
                let roundedTotal = roundNumber(total)
                transaction.setData(["destination": providerId, "name": name, "description": description, "total": roundedTotal, "quantity": quantity, "imageURL": imageURL], forDocument: itemRef)
            }
            return nil
        }) { (object, error) in
            if let error = error {
                complete(false, error)
            } else {
                complete(true, nil)
            }
        }
    }

    // FETCH USER CURRENT ORDER
    func fetchCurrentOrder(orderId: String, complete: @escaping (Bool?, Order?, Menu?, Error?) -> Void) {
        let ref = RefOrders.document(orderId)
        ref.getDocument { (snapshot, error) in
            if let error = error {
                complete(false, nil, nil, error)
            } else {
                guard let snapshot = snapshot, let data = snapshot.data() else {
                    complete(false, nil, nil, error)
                    return
                }
                let documentId =  snapshot.documentID
                let order = Order(key: documentId, data: data)
                ref.collection("items").getDocuments { (snapshot, error) in
                    if let error = error {
                        complete(false, nil, nil, error)
                    } else {
                        for document in snapshot!.documents {
                            let documentId =  document.documentID
                            let data = document.data()
                            let menu = Menu(key: documentId, data: data)
                            complete(true, order, menu, nil)
                        }
                    }
                }
            }
        }
    }

    // PLACE ORDER
    func placeOrder(order: Order, card: Card, complete: @escaping (Bool?, Error?) -> Void) {
        guard let orderId = order.id else { return }
        let ref = self.RefOrders.document(orderId)
        ref.getDocument { (snapshot, error) in
            guard let snapshot = snapshot, let bagData = snapshot.data() else { return }
            let subtotal = bagData["subtotal"] as! Double
            let total = bagData["total"] as! Double
            self.completeCharge(destination: order.providerId, destinationName: order.providerName, subtotal: subtotal, total: total, card: card) { (success, id, error) in
                if let error = error {
                    complete(false, error)
                } else {
                    complete(true, nil)
                }
            }
        }
    }
    
    // COMPLETE ORDER CHARGE
    func completeCharge(destination: String, destinationName: String, subtotal: Double, total: Double, card: Card?, complete: @escaping (Bool, String?, Error?) -> Void) {
        guard let number = card?.cardNumber, let month = card?.month, let year = card?.year, let cvv = card?.cvv else { return }
        
        let cardParams = STPCardParams()
        cardParams.number =  number
        cardParams.expMonth = month
        cardParams.expYear = year
        cardParams.cvc = cvv
        
        STPAPIClient.shared().createToken(withCard: cardParams) { (token: STPToken?, error: Error?) in
            guard let token = token, error == nil else {
                complete(false, nil, error)
                return
            }
            self.RefPaymentsMethods.document(token.tokenId).setData(["subtotal": subtotal, "total": total, "currency" : "usd", "payment_method": token.tokenId, "destination": destination, "provider_name": destinationName], merge: true) { (error) in
                if let error = error {
                    complete(false, nil, error)
                } else {
                    complete(true, token.tokenId, nil)
                }
            }
        }
    }
    
    
    // FETCH UPCOMING ORDERS
    func fetchUpcomingOrders(complete: @escaping (Order?, Error?) -> Void) {
        self.RefCurrentUser.collection("upcoming_orders").getDocuments { (snapshot, error) in
            if let error = error {
                complete(nil, error)
            } else {
                for document in snapshot!.documents {
                    let id = document.documentID
                    let data = document.data()
                    let order = Order(key: id, data: data)
                    complete(order, nil)
                }
            }
        }
    }
}
